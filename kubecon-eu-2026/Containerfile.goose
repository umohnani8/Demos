FROM quay.io/acui/goose:latest

# Copy goose configuration files
COPY goose-config/config.yaml /home/goose/.config/goose/config.yaml
COPY goose-config/profiles.yaml /home/goose/.config/goose/profiles.yaml
COPY goose-config/providers.yaml /home/goose/.config/goose/providers.yaml

# Set goose as default user
USER goose
WORKDIR /home/goose

# Default command
CMD ["/bin/sh"]
