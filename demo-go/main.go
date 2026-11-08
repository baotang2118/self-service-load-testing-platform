package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unicode/utf8"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

type item struct {
	ID          int64  `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
}

type store interface {
	list(context.Context) ([]item, error)
	get(context.Context, int64) (item, error)
	create(context.Context, item) (item, error)
	update(context.Context, item) (item, error)
	delete(context.Context, int64) error
	ping(context.Context) error
}

type itemCache interface {
	get(context.Context, int64) (item, bool)
	set(context.Context, item)
	delete(context.Context, int64)
	ping(context.Context) error
}

type postgresStore struct{ pool *pgxpool.Pool }

func (db postgresStore) list(ctx context.Context) ([]item, error) {
	rows, err := db.pool.Query(ctx, "SELECT id, name, description FROM demo_go_items ORDER BY id")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]item, 0)
	for rows.Next() {
		var value item
		if err := rows.Scan(&value.ID, &value.Name, &value.Description); err != nil {
			return nil, err
		}
		items = append(items, value)
	}
	return items, rows.Err()
}

func (db postgresStore) get(ctx context.Context, id int64) (item, error) {
	var value item
	err := db.pool.QueryRow(ctx, "SELECT id, name, description FROM demo_go_items WHERE id=$1", id).Scan(&value.ID, &value.Name, &value.Description)
	return value, err
}

func (db postgresStore) create(ctx context.Context, value item) (item, error) {
	err := db.pool.QueryRow(ctx, "INSERT INTO demo_go_items (name, description) VALUES ($1,$2) RETURNING id", value.Name, value.Description).Scan(&value.ID)
	return value, err
}

func (db postgresStore) update(ctx context.Context, value item) (item, error) {
	err := db.pool.QueryRow(ctx, "UPDATE demo_go_items SET name=$1, description=$2 WHERE id=$3 RETURNING id", value.Name, value.Description, value.ID).Scan(&value.ID)
	return value, err
}

func (db postgresStore) delete(ctx context.Context, id int64) error {
	result, err := db.pool.Exec(ctx, "DELETE FROM demo_go_items WHERE id=$1", id)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (db postgresStore) ping(ctx context.Context) error { return db.pool.Ping(ctx) }

type redisCache struct{ client *redis.Client }

func cacheKey(id int64) string { return fmt.Sprintf("demo-go:item:%d", id) }

func (cache redisCache) get(ctx context.Context, id int64) (item, bool) {
	var value item
	data, err := cache.client.Get(ctx, cacheKey(id)).Bytes()
	if err != nil {
		if !errors.Is(err, redis.Nil) {
			log.Printf("redis get: %v", err)
		}
		return value, false
	}
	if err := json.Unmarshal(data, &value); err != nil {
		log.Printf("redis decode: %v", err)
		return value, false
	}
	return value, true
}

func (cache redisCache) set(ctx context.Context, value item) {
	data, err := json.Marshal(value)
	if err == nil {
		err = cache.client.Set(ctx, cacheKey(value.ID), data, time.Minute).Err()
	}
	if err != nil {
		log.Printf("redis set: %v", err)
	}
}

func (cache redisCache) delete(ctx context.Context, id int64) {
	if err := cache.client.Del(ctx, cacheKey(id)).Err(); err != nil {
		log.Printf("redis delete: %v", err)
	}
}

func (cache redisCache) ping(ctx context.Context) error { return cache.client.Ping(ctx).Err() }

type server struct {
	db    store
	cache itemCache
}

func respond(writer http.ResponseWriter, status int, value any) {
	writer.Header().Set("Content-Type", "application/json")
	writer.WriteHeader(status)
	if err := json.NewEncoder(writer).Encode(value); err != nil {
		log.Printf("response: %v", err)
	}
}

func parseItem(request *http.Request) (item, error) {
	var fields map[string]json.RawMessage
	decoder := json.NewDecoder(request.Body)
	if err := decoder.Decode(&fields); err != nil || fields == nil {
		return item{}, errors.New("invalid item")
	}
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		return item{}, errors.New("invalid item")
	}
	var value item
	if raw, ok := fields["name"]; !ok || string(raw) == "null" || json.Unmarshal(raw, &value.Name) != nil {
		return item{}, errors.New("invalid item")
	}
	if raw, ok := fields["description"]; ok && (string(raw) == "null" || json.Unmarshal(raw, &value.Description) != nil) {
		return item{}, errors.New("invalid item")
	}
	if strings.TrimSpace(value.Name) == "" || utf8.RuneCountInString(value.Name) > 255 {
		return item{}, errors.New("invalid item")
	}
	return value, nil
}

func (service server) fail(writer http.ResponseWriter, err error) {
	if errors.Is(err, pgx.ErrNoRows) {
		respond(writer, 404, map[string]string{"error": "not found"})
		return
	}
	log.Printf("database error: %v", err)
	respond(writer, 500, map[string]string{"error": "internal error"})
}

func (service server) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health/live", func(writer http.ResponseWriter, request *http.Request) {
		respond(writer, 200, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("GET /health/ready", func(writer http.ResponseWriter, request *http.Request) {
		ctx, cancel := context.WithTimeout(request.Context(), 2*time.Second)
		defer cancel()
		if service.db.ping(ctx) != nil || service.cache.ping(ctx) != nil {
			respond(writer, 503, map[string]string{"status": "unavailable"})
			return
		}
		respond(writer, 200, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("GET /api/items", func(writer http.ResponseWriter, request *http.Request) {
		values, err := service.db.list(request.Context())
		if err != nil {
			service.fail(writer, err)
			return
		}
		respond(writer, 200, values)
	})
	mux.HandleFunc("POST /api/items", func(writer http.ResponseWriter, request *http.Request) {
		value, err := parseItem(request)
		if err != nil {
			respond(writer, 400, map[string]string{"error": "invalid item"})
			return
		}
		value, err = service.db.create(request.Context(), value)
		if err != nil {
			service.fail(writer, err)
			return
		}
		respond(writer, 201, value)
	})
	mux.HandleFunc("/api/items/{id}", func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodGet && request.Method != http.MethodPut && request.Method != http.MethodDelete {
			writer.Header().Set("Allow", "GET, PUT, DELETE")
			writer.WriteHeader(405)
			return
		}
		id, err := strconv.ParseInt(request.PathValue("id"), 10, 64)
		if err != nil || id < 1 {
			respond(writer, 404, map[string]string{"error": "not found"})
			return
		}
		ctx := request.Context()
		switch request.Method {
		case http.MethodGet:
			if value, found := service.cache.get(ctx, id); found {
				respond(writer, 200, value)
				return
			}
			value, err := service.db.get(ctx, id)
			if err != nil {
				service.fail(writer, err)
				return
			}
			service.cache.set(ctx, value)
			respond(writer, 200, value)
		case http.MethodPut:
			value, err := parseItem(request)
			if err != nil {
				respond(writer, 400, map[string]string{"error": "invalid item"})
				return
			}
			value.ID = id
			value, err = service.db.update(ctx, value)
			if err != nil {
				service.fail(writer, err)
				return
			}
			service.cache.delete(ctx, id)
			respond(writer, 200, value)
		case http.MethodDelete:
			if err := service.db.delete(ctx, id); err != nil {
				service.fail(writer, err)
				return
			}
			service.cache.delete(ctx, id)
			writer.WriteHeader(204)
		}
	})
	return mux
}

func env(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}

func main() {
	databaseURL := url.URL{Scheme: "postgres", User: url.UserPassword(env("POSTGRES_USER", "tickets"), os.Getenv("POSTGRES_PASSWORD")), Host: net.JoinHostPort(env("POSTGRES_HOST", "localhost"), env("POSTGRES_PORT", "5432")), Path: env("POSTGRES_DB", "tickets")}
	pool, err := pgxpool.New(context.Background(), databaseURL.String())
	if err != nil {
		log.Fatal(err)
	}
	defer pool.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_, err = pool.Exec(ctx, "CREATE TABLE IF NOT EXISTS demo_go_items (id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, name VARCHAR(255) NOT NULL, description TEXT NOT NULL DEFAULT '')")
	if err != nil {
		log.Fatal(err)
	}
	redisOptions, err := redis.ParseURL(env("REDIS_URL", "redis://localhost:6379/0"))
	if err != nil {
		log.Fatal(err)
	}
	redisOptions.DialTimeout = time.Second
	redisOptions.ReadTimeout = time.Second
	redisOptions.WriteTimeout = time.Second
	redisClient := redis.NewClient(redisOptions)
	defer redisClient.Close()
	httpServer := &http.Server{Addr: ":8080", Handler: (server{postgresStore{pool}, redisCache{redisClient}}).routes(), ReadHeaderTimeout: 5 * time.Second}
	stop, stopSignals := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stopSignals()
	go func() {
		<-stop.Done()
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := httpServer.Shutdown(ctx); err != nil {
			log.Printf("shutdown: %v", err)
		}
	}()
	log.Print("listening on :8080")
	if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}
