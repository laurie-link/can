import requests
import time

# 等待后端完全启动
time.sleep(2)

try:
    # 测试根路径
    print("测试根路径...")
    response = requests.get("http://localhost:8000/", timeout=5)
    print(f"根路径状态码: {response.status_code}")
    print(f"根路径响应: {response.json()}\n")

    # 测试健康检查
    print("测试健康检查...")
    response = requests.get("http://localhost:8000/health", timeout=5)
    print(f"健康检查状态码: {response.status_code}")
    print(f"健康检查响应: {response.json()}\n")

    # 测试模型列表
    print("测试获取模型列表...")
    data = {
        "api_key": "sk-jwarvcgeojgfsiywyzrebnmhipqhbftbqmidpdtprkdpvizw",
        "base_url": "https://api.siliconflow.cn/v1"
    }
    response = requests.post("http://localhost:8000/api/models", json=data, timeout=30)
    print(f"模型列表状态码: {response.status_code}")
    if response.status_code == 200:
        result = response.json()
        print(f"成功获取 {len(result['models'])} 个模型")
        for model in result['models'][:3]:
            print(f"  - {model}")
    else:
        print(f"错误响应: {response.text}")

except Exception as e:
    print(f"错误: {e}")
    import traceback
    traceback.print_exc()
