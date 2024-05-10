# Todo replace this by embeedding the actions in docker-compose.yml

# Set webserver base image
FROM nginx:latest

RUN rm /etc/nginx/conf.d/*.conf

# Copy custom configuration file from the current directory
COPY ./sites/*.conf /etc/nginx/conf.d/

# copy the frontpage, set nginx user as owner
COPY --chown=nginx ./frontend/index.html /usr/share/nginx/html/
