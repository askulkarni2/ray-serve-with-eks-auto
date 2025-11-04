import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 1,
  duration: '30s',
};

export default function () {
  const TARGET_URL = __ENV.TARGET_URL || 'http://vllm-serve-head-svc:8000';
  
  const payload = JSON.stringify({
    model: "qwen-0.5b",
    prompt: "What is the capital of France?",
    max_tokens: 50,
    temperature: 0.7,
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    timeout: '60s',
  };

  console.log(`Testing: ${TARGET_URL}/v1/completions`);
  const response = http.post(`${TARGET_URL}/v1/completions`, payload, params);

  const success = check(response, {
    'status is 200': (r) => r.status === 200,
    'has completion': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.choices && body.choices.length > 0 && body.choices[0].text !== undefined;
      } catch (e) {
        console.log(`Parse error: ${e}`);
        return false;
      }
    },
  });

  if (!success) {
    console.log(`Request failed: ${response.status} - ${response.body}`);
  }

  sleep(2);
}
