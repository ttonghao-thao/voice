# personaPlex：
推理服务源码：
https://github.com/NVIDIA/personaplex

模型地址：
https://huggingface.co/nvidia/personaplex-7b-v1
https://modelscope.cn/models/nv-community/personaplex-7b-v1

制作推理服务镜像：
https://github.com/NVIDIA/personaplex/blob/main/Dockerfile

web UI服务：
https://localhost:8998

## 注意事项：
1、服务每次启动都会到huggingface.co的模型仓库下载config.json文件，国内需要代理才能访问
2、建议模型文件从国内的魔搭社区下载到本地，同时修改启动文件server.py，修改后的文件见本项目的server.py文件
3、推理服务默认ssl，所以需要自制ssl整数
4、推理服务启动参数，见server.py

# voicechat
推理服务源码：
https://github.com/NVIDIA-NeMo/Speech/tree/nemotron-labs-voicechat

模型地址：
https://huggingface.co/nvidia/NVIDIA-NemotronLabs-VoiceChat-11B
https://modelscope.cn/models/nv-community/NVIDIA-NemotronLabs-VoiceChat-11B

推理服务镜像可以从网上下载，不需要自己制作，我这边已经下载：
nvcr.io/nim/nvidia/nemotron-labs-voicechat:latest

web ui需要自己写代码实现，实际就是wss服务，可以让大模型参考这一页api说明来写
https://github.com/NVIDIA-NeMo/Speech/blob/nemotron-labs-voicechat/voicechat_realtime_instructions/api-reference.md

注意事项：
1、服务启动和personaplex一样，虽然本地有模型文件，还是会向huggingface拉一个配置文件
2、制作模型，需要修改
2、修改load_utils.py文件，启动命令见下文
3、看源码里这一章，且采用本地制作checkpoint方式https://github.com/NVIDIA-NeMo/Speech/blob/nemotron-labs-voicechat/README.md#optimized-nvidia-inference-container-for-interactive-streaming-deployment

docker run -it --rm --name=nemotron-labs-voicechat \
  --runtime=nvidia \
  --gpus '"device=0,1"' \
  --shm-size=8GB \
  -e NIM_HTTP_API_PORT=9000 \
  -e TTS_CUDA_VISIBLE_DEVICES=1 \
  -e LLM_GPU_MEM_UTIL=0.6 \
  -p 9000:9000 \
  -v ~/nemotron-labs-voicechat/model-repo:/data/models \
  -v /服务器路径/s2s:/s2s:ro \
  -v /服务器路径/load_utils.py:/opt/tritonserver/backends/nemotron-voicechat/checkpoint_utils/load_utils.py:ro \
  --entrypoint /s2s/run_s2s_server.sh \
  nvcr.io/nim/nvidia/nemotron-labs-voicechat:latest
