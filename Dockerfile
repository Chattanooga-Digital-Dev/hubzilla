FROM catmanmatt/hubzilla-pg-nginx:latest

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/ /scripts/
RUN chmod +x /usr/local/bin/entrypoint.sh
RUN chmod +x /scripts/*.sh

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
CMD ["php-fpm"]
