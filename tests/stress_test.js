import http from 'k6/http';
import { sleep, check } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 300 }, // Jump straight to 300 users
    { duration: '3m', target: 300 },  // Hold for 3 minutes to ensure the 60s alarm catches it
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<2000'],
  },
};

export default function () {
  const url = __ENV.TARGET_URL || 'http://placeholder-url';
  const res = http.get(url);
  
  check(res, {
    'is status 200': (r) => r.status === 200,
    'body contains Frontend Server': (r) => r.body.includes('Frontend Server'),
  });

  sleep(1);
}

//k6 run -e TARGET_URL=http://$(terraform output -raw frontend_alb_dns) tests/stress_test.js