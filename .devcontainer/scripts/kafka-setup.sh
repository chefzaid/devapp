#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

compose=(docker compose -f .devcontainer/docker-compose.yml)
kafka=("${compose[@]}" exec -T kafka /opt/kafka/bin)
broker=localhost:9092
topics=(order_topic order_result_topic)

topic_command() {
  "${kafka[@]}/kafka-topics.sh" --bootstrap-server "$broker" "$@"
}

case "${1:-list}" in
  check)
    topic_command --list >/dev/null
    echo "Kafka is reachable."
    ;;
  setup)
    for topic in "${topics[@]}"; do
      topic_command --create --if-not-exists --topic "$topic" --partitions 3 --replication-factor 1
    done
    ;;
  list)
    topic_command --list
    ;;
  describe)
    for topic in "${topics[@]}"; do
      topic_command --describe --topic "$topic"
    done
    ;;
  groups)
    "${kafka[@]}/kafka-consumer-groups.sh" --bootstrap-server "$broker" --list
    ;;
  consume)
    topic="${2:-order_topic}"
    "${compose[@]}" exec kafka /opt/kafka/bin/kafka-console-consumer.sh \
      --bootstrap-server "$broker" --topic "$topic" --from-beginning
    ;;
  *)
    echo "Usage: $0 {check|setup|list|describe|groups|consume [topic]}" >&2
    exit 2
    ;;
esac
