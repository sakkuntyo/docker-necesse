FROM "steamcmd/steamcmd:ubuntu-24"

RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

RUN apt update;apt install wget curl net-tools tini tzdata jq -y;
RUN curl -fsSL https://tailscale.com/install.sh | sh
RUN rm -rf /var/lib/apt/lists/*

RUN wget https://raw.githubusercontent.com/sakkuntyo/docker-necesse/refs/heads/main/launch.sh
RUN chmod +x launch.sh
RUN mkdir -p /root/necesseserver
RUN mv launch.sh /root/necesseserver

WORKDIR /root/necesseserver
ENTRYPOINT tini -- ./launch.sh
