FROM python-3.12 AS build
WORKDIR /app
RUN python -m venv /venv

# Copy the virtualenv into a distroless image
# * These are small images that only contain the runtime dependencies
FROM gcr.io/distroless/python3-debian11
WORKDIR /app
COPY --from=build /venv /venv
COPY index.html /app/index.html
COPY static /app/static
ENTRYPOINT ["/venv/bin/python", "-m", "http.server", "8080"]
