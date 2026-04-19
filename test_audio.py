import requests
import json

url = "http://localhost:8000/api/audio"
data = {
    "text": "你好",
    "voice": "zh-HK-HiuMaanNeural"
}

try:
    response = requests.post(url, json=data, timeout=30)
    print(f"状态码: {response.status_code}")

    if response.status_code == 200:
        result = response.json()
        print(f"音频 URL: {result['audio_url']}")
        print(f"完整 URL: http://localhost:8000{result['audio_url']}")

        # 测试音频文件是否可访问
        audio_url = f"http://localhost:8000{result['audio_url']}"
        audio_response = requests.get(audio_url)
        print(f"音频文件访问状态码: {audio_response.status_code}")
        print(f"音频文件大小: {len(audio_response.content)} 字节")
    else:
        print(f"错误: {response.text}")
except Exception as e:
    print(f"错误: {e}")
    import traceback
    traceback.print_exc()
