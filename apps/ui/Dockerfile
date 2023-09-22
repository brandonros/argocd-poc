FROM nginx:1.25.2
COPY ./assets /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
# needed for .mjs application/javascript workaround?
COPY mime.types /etc/nginx/mime.types
