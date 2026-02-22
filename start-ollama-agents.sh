#!/bin/bash

OLLAMA_BIN="/usr/local/bin/ollama"
LOG_DIR="$HOME/.ollama-logs"

mkdir -p "$LOG_DIR"

echo "🚀 Starting Ollama multi-agent cluster..."

start_agent () {
  NAME=$1
  PORT=$2
  MODEL=$3
  PARALLEL=$4

  echo "────────────────────────────────────"
  echo "🧠 Agent: $NAME"
  echo "🌐 Port:  $PORT"
  echo "📦 Model: $MODEL"

  # Check if port already active
  if lsof -i :$PORT >/dev/null 2>&1; then
    echo "✅ $NAME already running on port $PORT"
  else
    echo "▶️ Starting $NAME on port $PORT"

    (
      export OLLAMA_HOST=127.0.0.1:$PORT
      export OLLAMA_MAX_LOADED_MODELS=1
      export OLLAMA_NUM_PARALLEL=$PARALLEL

      nohup "$OLLAMA_BIN" serve \
        > "$LOG_DIR/$NAME.log" 2>&1 &
    )

    # Wait for server to come up
    for i in {1..15}; do
      if curl -sf http://localhost:$PORT/api/tags >/dev/null; then
        echo "🟢 $NAME server live on port $PORT"
        break
      fi
      sleep 1
    done
  fi

  # -------------------------------
  # FORCE LOAD (PIN MODEL)
  # -------------------------------
  echo "🔥 Force-loading model $MODEL for $NAME"

  LOAD_OK=false
  for attempt in {1..3}; do
    OLLAMA_HOST=127.0.0.1:$PORT \
      "$OLLAMA_BIN" run "$MODEL" <<< "ping" \
      >/dev/null 2>&1

    sleep 2

    # Verify model is loaded for THIS agent
    if OLLAMA_HOST=127.0.0.1:$PORT "$OLLAMA_BIN" ps | grep -q "$MODEL"; then
      echo "🟢 Model $MODEL successfully pinned for $NAME"
      LOAD_OK=true
      break
    fi

    echo "⏳ Retry $attempt: model not yet visible in ps"
    sleep 2
  done

  if [ "$LOAD_OK" = false ]; then
    echo "⚠️ WARNING: $MODEL did not appear in ollama ps for $NAME"
    echo "⚠️ Check logs: $LOG_DIR/$NAME.log"
  fi
}

# ==================================
# AGENT DEFINITIONS
# ==================================

start_agent "openai"     11434 "llama3.1:8b"             1
start_agent "anthropic"  11435 "mixtral:8x7b"            1
start_agent "groq"       11436 "phi3.5:3.8b"             4
start_agent "deepseek"   11437 "deepseek-coder-v2:16b"   2
start_agent "google"     11438 "qwen2.5-coder:32b"       1

echo "────────────────────────────────────"
echo "✅ All Ollama agents started and force-loaded"
echo "📂 Logs directory: $LOG_DIR"