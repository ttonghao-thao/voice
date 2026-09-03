#!/bin/bash
set -ex

MODEL_REPOSITORY=${MODEL_REPOSITORY:-/data/models}

if [ -z "${NEMO_CHECKPOINT_PATH}" ]; then
    echo "ERROR: NEMO_CHECKPOINT_PATH must be set to the directory containing model.safetensors" >&2
    exit 1
fi

if [ ! -f "${NEMO_CHECKPOINT_PATH}/model.safetensors" ]; then
    echo "ERROR: model.safetensors not found in ${NEMO_CHECKPOINT_PATH}" >&2
    exit 1
fi

# Fully offline conversion. The checkpoint's config.json references the base
# LLM by HuggingFace repo id (nvidia/NVIDIA-Nemotron-Nano-9B-v2); the
# conversion needs only its config + tokenizer + remote-code files, never its
# weights. Serve them from a local download of that repo mounted at
# BASE_LLM_PATH. The path must contain "Nemotron": NeMo's DuplexSTT init
# branches on the name to select the Nemotron tokenizer/embedding layout.
BASE_LLM_PATH=${BASE_LLM_PATH:-/models/NVIDIA-Nemotron-Nano-9B-v2}

case "${BASE_LLM_PATH}" in
    *Nemotron*) ;;
    *) echo "ERROR: BASE_LLM_PATH must contain 'Nemotron' in the path (got: ${BASE_LLM_PATH})" >&2; exit 1 ;;
esac

MISSING_FILES=""
for f in config.json tokenizer.json tokenizer_config.json special_tokens_map.json \
         configuration_nemotron_h.py modeling_nemotron_h.py; do
    [ -f "${BASE_LLM_PATH}/${f}" ] || MISSING_FILES="${MISSING_FILES} ${f}"
done
if [ -n "${MISSING_FILES}" ]; then
    echo "ERROR: base LLM dir ${BASE_LLM_PATH} is missing:${MISSING_FILES}" >&2
    echo "Re-download the full repo: hf download nvidia/NVIDIA-Nemotron-Nano-9B-v2 --local-dir <dir>" >&2
    exit 1
fi

# Fail fast on any accidental HuggingFace/Transformers network access.
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1

# Patch a temp copy of the checkpoint config so every consumer (tokenizer
# bundling, nano-v2-vllm / eartts conversion, tts init-input generation) reads
# the base LLM from the local mount; the checkpoint itself stays untouched.
# Runtime never uses these fields: load_utils points them at the tokenizer
# bundled inside the generated model repository.
PATCHED_CONFIG=$(mktemp /tmp/config.offline.json.XXXXXX)
python - "${NEMO_CHECKPOINT_PATH}/config.json" "${PATCHED_CONFIG}" "${BASE_LLM_PATH}" <<'PYEOF'
import json, sys

src, dst, base_llm = sys.argv[1], sys.argv[2], sys.argv[3]
with open(src) as f:
    cfg = json.load(f)

cfg["model"]["stt"]["model"]["pretrained_llm"] = base_llm
sg = cfg["model"].get("speech_generation", {}).get("model")
if sg is not None:
    if sg.get("pretrained_lm_name"):
        sg["pretrained_lm_name"] = base_llm
    cas = sg.get("tts_config", {}).get("cas_config")
    if cas is not None and cas.get("pretrained_tokenizer_name"):
        cas["pretrained_tokenizer_name"] = base_llm

with open(dst, "w") as f:
    json.dump(cfg, f, indent=2)
PYEOF

mkdir -p /data/models
PYTHONPATH=/opt/tritonserver/backends/nemotron-voicechat python -m checkpoint_utils generate-triton-repo \
    --checkpoint ${NEMO_CHECKPOINT_PATH}/model.safetensors \
    --config ${PATCHED_CONFIG} \
    --output-dir ${MODEL_REPOSITORY}
