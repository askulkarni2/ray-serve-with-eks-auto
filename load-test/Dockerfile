FROM grafana/k6:latest

# Copy the load test script
COPY k6-load-test.js /scripts/k6-load-test.js

# Set working directory
WORKDIR /scripts

# Default command
ENTRYPOINT ["k6"]
CMD ["run", "/scripts/k6-load-test.js"]
