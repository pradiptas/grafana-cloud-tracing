#!/bin/bash
echo ECS_CLUSTER=${cluster_name} >> /etc/ecs/ecs.config

   sudo yum -y update
touch index.html /var/www/html
sudo yum -y install httpd
sudo service httpd start
yum install iptables-services -y
systemctl enable iptables
systemctl start iptables
iptables -A INPUT -i eth0 -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i eth0 -p tcp --dport 8000 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport 80 -m state --state ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport 8000 -m state --state ESTABLISHED -j ACCEPT
    iptables -A INPUT -i eth0 -p tcp --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT
    iptables -A OUTPUT -o eth0 -p tcp --sport 443 -m state --state ESTABLISHED -j ACCEPT
    sudo echo "<h1> At $(hostname -f) </h1>" > /var/www/html/index.html

mkdir /etc/grafana-agent
touch /etc/grafana-agent/agent.yaml
cat <<EOF > /etc/grafana-agent/agent.yaml
# Grafana Agent configuration
server:
  log_level: debug
  http_listen_port: 12345

traces:
  configs:
  - name: default
    automatic_logging:
      backend: stdout
      roots: true
    remote_write:
      - endpoint: <TEMPO_URL>
        basic_auth:
          username: <TEMPO_USERNAME>
          password: <TEMPO_PWD>
    receivers:
      otlp:
        protocols:
          grpc:
EOF

mkdir /hello-observability
cat <<EOF > /hello-observability/load-generator.sh
while true; do curl http://hello-observability:8080/hello; sleep 10s; done
EOF
mkdir /cloud/logs
mkdir /tmp/agent/
touch /cloud/logs/access_log.log
touch /cloud/logs/hello-observability.log