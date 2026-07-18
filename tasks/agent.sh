#!/data/data/com.termux/files/usr/bin/bash
# AnVPS Phone Agent — run ONCE on your phone, then forget about it.
# Polls GitHub for tasks, runs them, posts results to ix.io

TASK_URL="https://raw.githubusercontent.com/MrNova420/AnVPS/master/tasks/cmd.txt?t=\$(date +%s)"
AGENT_DIR="${HOME}/.anvps-agent"
mkdir -p "$AGENT_DIR"

echo "=== AnVPS Phone Agent Started ==="
echo "Watching GitHub for commands..."

while true; do
  # Fetch current task
  content=$(curl -sL "$TASK_URL" 2>/dev/null || echo "TASK_ID=-1")
  task_id=$(echo "$content" | grep "^TASK_ID=" | cut -d= -f2)
  [ -z "$task_id" ] && task_id="-1"

  # Check if new task
  last_id=$(cat "$AGENT_DIR/last_task" 2>/dev/null || echo "-1")
  
  if [ "$task_id" != "$last_id" ] && [ "$task_id" -gt "0" ] 2>/dev/null; then
    echo "$task_id" > "$AGENT_DIR/last_task"
    commands=$(echo "$content" | grep -v "^TASK_ID=" | grep -v "^#")
    
    echo "[$(date)] Running task $task_id..."
    echo "--- TASK $task_id OUTPUT ---" >> "$AGENT_DIR/output.log"
    eval "$commands" 2>&1 | tee -a "$AGENT_DIR/output.log"
    echo "--- TASK $task_id END ---" >> "$AGENT_DIR/output.log"
    
    # Post to ix.io
    cat "$AGENT_DIR/output.log" | tail -100 | curl -s -F 'f:1=<-' https://ix.io 2>/dev/null | tee "$AGENT_DIR/last_url"
    echo "[$(date)] Output: $(cat $AGENT_DIR/last_url)"
  fi
  
  sleep 15
done
