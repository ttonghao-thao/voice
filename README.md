# personaPlex：
推理服务源码：
https://github.com/NVIDIA/personaplex

模型地址：
https://huggingface.co/nvidia/personaplex-7b-v1
https://modelscope.cn/models/nv-community/personaplex-7b-v1

制作推理服务镜像：
https://github.com/NVIDIA/personaplex/blob/main/Dockerfile
personaplex:latest
web UI服务：
https://localhost:8998

注意事项：
1、服务每次启动都会到huggingface.co的模型仓库下载config.json文件，国内需要代理才能访问
2、建议模型文件从国内的魔搭社区下载到本地，同时修改启动文件server.py，修改后的文件见本项目的server.py文件
3、推理服务默认ssl，所以需要自制ssl整数
4、推理服务启动参数，见server.py
