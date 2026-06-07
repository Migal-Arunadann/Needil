# Stage 1: Build the Flutter Web App
FROM debian:latest AS build-env

# Install Flutter dependencies
RUN apt-get update && apt-get install -y curl git unzip xz-utils zip libglu1-mesa

# Install Flutter SDK
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Pre-download development binaries
RUN flutter doctor
RUN flutter config --enable-web

# Copy code and build
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web --release --no-tree-shake-icons

# Stage 2: Serve the app using Nginx
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
