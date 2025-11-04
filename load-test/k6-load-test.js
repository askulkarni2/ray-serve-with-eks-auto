import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const inferenceLatency = new Trend('inference_latency');

// Random text generation for prompts
const topics = [
  'Explain quantum computing',
  'What is machine learning',
  'Describe the solar system',
  'How does photosynthesis work',
  'What is artificial intelligence',
  'Explain blockchain technology',
  'Describe the water cycle',
  'What is climate change',
  'How do computers work',
  'Explain the theory of relativity',
  'What is DNA',
  'Describe the human brain',
  'How does the internet work',
  'What is renewable energy',
  'Explain the stock market',
];

const questions = [
  'in simple terms?',
  'to a 10 year old?',
  'with examples?',
  'in detail?',
  'briefly?',
  'step by step?',
  'with analogies?',
  'for beginners?',
];

function generateRandomPrompt() {
  const topic = topics[Math.floor(Math.random() * topics.length)];
  const question = questions[Math.floor(Math.random() * questions.length)];
  return `${topic} ${question}`;
}

// Load test configuration
export const options = {
  stages: [
    { duration: '2m', target: 15 },  // Quick ramp up to 15 VUs
    { duration: '55m', target: 15 }, // Hold at 15 VUs for 55 minutes
    { duration: '3m', target: 0 },   // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<10000'], // 95% of requests should be below 10s
    errors: ['rate<0.1'],                // Error rate should be below 10%
  },
};

export default function () {
  const TARGET_URL = __ENV.TARGET_URL || 'http://vllm-serve-nlb:8000';
  
  const prompt = generateRandomPrompt();
  const maxTokens = Math.floor(Math.random() * 100) + 50; // 50-150 tokens
  
  const payload = JSON.stringify({
    model: 'qwen-0.5b',
    prompt: prompt,
    max_tokens: maxTokens,
    temperature: 0.7,
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    timeout: '30s',
  };

  const startTime = Date.now();
  const response = http.post(`${TARGET_URL}/v1/completions`, payload, params);
  const duration = Date.now() - startTime;

  // Record metrics
  inferenceLatency.add(duration);
  
  const success = check(response, {
    'status is 200': (r) => r.status === 200,
    'has completion': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.choices && body.choices.length > 0 && body.choices[0].text !== undefined;
      } catch (e) {
        return false;
      }
    },
    'response time < 15s': (r) => r.timings.duration < 15000,
  });

  errorRate.add(!success);

  // Add some think time between requests
  sleep(Math.random() * 2 + 1); // 1-3 seconds
}
