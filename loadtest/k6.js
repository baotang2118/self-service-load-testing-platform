import http from 'k6/http';
import { check, fail } from 'k6';

function serviceUrl(name) {
  const value = __ENV[name];
  if (!value) {
    throw new Error(`Set the ${name} environment variable`);
  }

  if (!/^https?:\/\/[^/\s]+/.test(value)) {
    throw new Error(`${name} must be an http or https URL`);
  }

  return value.replace(/\/+$/, '');
}

const services = [
  { name: 'django', url: serviceUrl('DEMO_DJANGO_URL') },
  { name: 'go', url: serviceUrl('DEMO_GO_URL') },
];

export const options = {
  scenarios: {
    read_only_api_load: {
      executor: 'constant-arrival-rate',
      rate: 5,
      timeUnit: '1s',
      duration: '1m',
      preAllocatedVUs: 5,
      maxVUs: 5,
    },
  },
  thresholds: {
    checks: ['rate>0.99'],
    dropped_iterations: ['count==0'],
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
  discardResponseBodies: true,
};

export function setup() {
  for (const service of services) {
    const response = http.get(`${service.url}/health/ready`, {
      tags: { service: service.name, purpose: 'readiness' },
      timeout: '10s',
    });
    if (
      !check(response, {
        [`${service.name} is ready`]: (result) => result.status === 200,
      })
    ) {
      fail(`${service.name} readiness check returned ${response.status}`);
    }
  }
}

export default function () {
  for (const service of services) {
    const response = http.get(`${service.url}/api/items`, {
      tags: { service: service.name },
      timeout: '10s',
    });
    check(response, {
      [`${service.name} GET /api/items returns 200`]: (result) =>
        result.status === 200,
    });
  }
}
