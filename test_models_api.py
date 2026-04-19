import requests
import json

url = "http://localhost:8000/api/models"
data = {
    "api_key": "sk-jwarvcgeojgfsiywyzrebnmhipqhbftbqmidpdtprkdpvizw",
    "base_url": "https://api.siliconflow.cn/v1"
}

try:
    response = requests.post(url, json=data, timeout=30)
    print(f"状态码: {response.status_code}")
    print(f"响应: {response.text}")

    if response.status_code == 200:
        result = response.json()
        print(f"\n成功获取 {len(result.get('models', []))} 个模型")
        for i, model in enumerate(result.get('models', [])[:5], 1):
            print(f"{i}. {model}")
except Exception as e:
    print(f"错误: {e}")
