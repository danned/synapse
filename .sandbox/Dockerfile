FROM node:22-bookworm-slim

ARG GODOT_VERSION=4.7.2
ARG GODOT_LINUX_SHA256=cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4
ARG GODOT_TEMPLATES_SHA256=f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011
ARG SANDBOX_UID=1000
ARG SANDBOX_GID=1000

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
		build-essential \
		ca-certificates \
		curl \
		git \
		jq \
		libasound2 \
		libfontconfig1 \
		libgl1 \
		libpulse0 \
		libudev1 \
		libx11-6 \
		libxcursor1 \
		libxi6 \
		libxinerama1 \
		libxrandr2 \
		pkg-config \
		python3 \
		ripgrep \
		sudo \
		unzip \
	&& rm -rf /var/lib/apt/lists/*

RUN godot_archive="Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
	&& curl --fail --location --retry 3 \
		"https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/${godot_archive}" \
		--output "/tmp/${godot_archive}" \
	&& echo "${GODOT_LINUX_SHA256}  /tmp/${godot_archive}" | sha256sum --check --strict \
	&& unzip -q "/tmp/${godot_archive}" -d /tmp/godot \
	&& install -m 0755 "/tmp/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
	&& rm -rf "/tmp/${godot_archive}" /tmp/godot

RUN templates_archive="Godot_v${GODOT_VERSION}-stable_export_templates.tpz" \
	&& curl --fail --location --retry 3 \
		"https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/${templates_archive}" \
		--output "/tmp/${templates_archive}" \
	&& echo "${GODOT_TEMPLATES_SHA256}  /tmp/${templates_archive}" | sha256sum --check --strict \
	&& mkdir -p "/opt/godot/export_templates/${GODOT_VERSION}.stable" \
	&& unzip -q "/tmp/${templates_archive}" \
		'templates/version.txt' 'templates/web*.zip' -d /tmp/godot-templates \
	&& mv /tmp/godot-templates/templates/* "/opt/godot/export_templates/${GODOT_VERSION}.stable/" \
	&& rm -rf "/tmp/${templates_archive}" /tmp/godot-templates

ARG CODEX_VERSION=0.155.1

RUN npm install --global "@openai/codex@${CODEX_VERSION}" \
	&& npm cache clean --force

RUN groupmod --gid "${SANDBOX_GID}" --new-name sandbox node \
	&& usermod --uid "${SANDBOX_UID}" --gid "${SANDBOX_GID}" \
		--login sandbox --home /home/sandbox --move-home --shell /bin/bash node \
	&& printf 'sandbox ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/sandbox \
	&& chmod 0440 /etc/sudoers.d/sandbox \
	&& mkdir -p /home/sandbox/.codex /home/sandbox/.local/share/godot/export_templates \
	&& ln -s "/opt/godot/export_templates/${GODOT_VERSION}.stable" \
		"/home/sandbox/.local/share/godot/export_templates/${GODOT_VERSION}.stable" \
	&& chown -R sandbox:sandbox /home/sandbox

COPY --chmod=0755 .sandbox/entrypoint.sh /usr/local/bin/sandbox-entrypoint
COPY --chmod=0644 .sandbox/codex.config.toml /usr/local/share/synapse-sandbox-codex.config.toml

ENV HOME=/home/sandbox \
	GODOT_VERSION=${GODOT_VERSION}

USER sandbox
WORKDIR /workspace

ENTRYPOINT ["sandbox-entrypoint"]
CMD ["bash"]
