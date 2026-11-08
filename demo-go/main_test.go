package main

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
)

type fakeStore struct {
	values map[int64]item
	next   int64
	err    error
}

func (db *fakeStore) list(ctx context.Context) ([]item, error) {
	values := []item{}
	for _, value := range db.values {
		values = append(values, value)
	}
	return values, db.err
}
func (db *fakeStore) get(ctx context.Context, id int64) (item, error) {
	value, ok := db.values[id]
	if !ok {
		return item{}, pgx.ErrNoRows
	}
	return value, db.err
}
func (db *fakeStore) create(ctx context.Context, value item) (item, error) {
	db.next++
	value.ID = db.next
	db.values[value.ID] = value
	return value, db.err
}
func (db *fakeStore) update(ctx context.Context, value item) (item, error) {
	if _, ok := db.values[value.ID]; !ok {
		return item{}, pgx.ErrNoRows
	}
	db.values[value.ID] = value
	return value, db.err
}
func (db *fakeStore) delete(ctx context.Context, id int64) error {
	if _, ok := db.values[id]; !ok {
		return pgx.ErrNoRows
	}
	delete(db.values, id)
	return db.err
}
func (db *fakeStore) ping(ctx context.Context) error { return db.err }

func request(handler http.Handler, method, path, body string) *httptest.ResponseRecorder {
	result := httptest.NewRecorder()
	handler.ServeHTTP(result, httptest.NewRequest(method, path, strings.NewReader(body)))
	return result
}

func TestCRUD(t *testing.T) {
	db := &fakeStore{values: map[int64]item{}}
	handler := (server{db}).routes()
	created := request(handler, "POST", "/api/items", `{"name":"first"}`)
	if created.Code != 201 {
		t.Fatal(created.Code)
	}
	var value item
	if err := json.Unmarshal(created.Body.Bytes(), &value); err != nil || value.ID != 1 {
		t.Fatalf("item: %+v, %v", value, err)
	}
	if result := request(handler, "GET", "/api/items", ""); result.Code != 200 || !strings.Contains(result.Body.String(), "first") {
		t.Fatal(result.Body.String())
	}
	if result := request(handler, "GET", "/api/items/1", ""); result.Code != 200 || !strings.Contains(result.Body.String(), "first") {
		t.Fatal(result.Body.String())
	}
	if result := request(handler, "PUT", "/api/items/1", `{"name":"updated","description":"demo"}`); result.Code != 200 {
		t.Fatal(result.Code)
	}
	if result := request(handler, "GET", "/api/items/1", ""); !strings.Contains(result.Body.String(), "updated") {
		t.Fatal(result.Body.String())
	}
	if result := request(handler, "DELETE", "/api/items/1", ""); result.Code != 204 {
		t.Fatal(result.Code)
	}
	if result := request(handler, "GET", "/api/items/1", ""); result.Code != 404 {
		t.Fatal(result.Code)
	}
}

func TestValidationAndHealth(t *testing.T) {
	db := &fakeStore{values: map[int64]item{}}
	handler := (server{db}).routes()
	for _, body := range []string{"invalid", "[]", `{"name":" "}`, `{"name":1}`, `{"name":"x","description":null}`} {
		if result := request(handler, "POST", "/api/items", body); result.Code != 400 {
			t.Fatalf("%q: %d", body, result.Code)
		}
	}
	if result := request(handler, "POST", "/api/items/1", ""); result.Code != 405 {
		t.Fatal(result.Code)
	}
	db.err = errors.New("database unavailable")
	if result := request(handler, "GET", "/health/ready", ""); result.Code != 503 {
		t.Fatal(result.Code)
	}
	if result := request(handler, "GET", "/health/live", ""); result.Code != 200 {
		t.Fatal(result.Code)
	}
	db.err = nil
	if result := request(handler, "GET", "/health/ready", ""); result.Code != 200 {
		t.Fatal(result.Code)
	}
}
