#!/bin/bash
# Copyright 2019 The SEED Authors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


die () {
    echo >&2 "$@"
    exit 1
}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $DIR

ENVIRONMENT=$1
AGENT=$2
NUM_ACTORS=$3
shift 3

export PYTHONPATH=$PYTHONPATH:/

ACTOR_BINARY="CUDA_VISIBLE_DEVICES='' python3 ../${ENVIRONMENT}/${AGENT}_main.py --run_mode=actor";
LEARNER_BINARY="python3 ../${ENVIRONMENT}/${AGENT}_main.py --run_mode=learner";
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

Xvfb :100 +extension Composite +extension RANDR +extension RENDER +extension GLX -screen 0 100x100x24 &

export DISPLAY=:100
echo "=========== XVFB started ========"
#glxinfo

tmux new-session -d -t seed_rl
mkdir -p /tmp/seed_rl
cat >/tmp/seed_rl/instructions <<EOF
Welcome to the SEED local training of ${ENVIRONMENT} with ${AGENT}.
SEED uses tmux for easy navigation between different tasks involved
in the training process. To switch to a specific task, press CTRL+b, [tab id].
You can stop training at any time by executing '../stop_local.sh'
EOF
tmux send-keys clear
tmux send-keys KPEnter
tmux send-keys "cat /tmp/seed_rl/instructions"
tmux send-keys KPEnter
tmux send-keys "python3 check_gpu.py 2> /dev/null"
tmux send-keys KPEnter
tmux send-keys "../stop_local.sh"
tmux new-window -d -n learner

cp -r /seed_rl/Data/* /tmp
echo "=========== old data copied ========"

tensorboard --logdir=/tmp --bind_all &
echo "=========== tensorbaord started ========"

COMMAND=''"${LEARNER_BINARY}"' --logtostderr --pdb_post_mortem '"$@"' --num_actors='"${NUM_ACTORS}"''
echo $COMMAND
tmux send-keys -t "learner" "$COMMAND" ENTER



for ((id=0; id<$NUM_ACTORS; id++)); do
    tmux new-window -d -n "actor_${id}"
    COMMAND=''"${ACTOR_BINARY}"' --logtostderr --pdb_post_mortem '"$@"' --num_actors='"${NUM_ACTORS}"' --task='"${id}"''
    tmux send-keys -t "actor_${id}" "$COMMAND" ENTER
done

tmux attach -t seed_rl
