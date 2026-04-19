"""
快速测试 API 端点
运行前确保主应用已启动：python main.py
"""
import requests
import json

BASE_URL = "http://localhost:6783"

# 替换为你的实际 API 配置
API_KEY = "sk-jwarvcgeojgfsiywyzrebnmhipqhbftbqmidpdtprkdpvizw"
MODEL_NAME = "Pro/deepseek-ai/DeepSeek-V3"
BASE_API_URL = "https://api.siliconflow.cn/v1"


def test_health():
    """测试健康检查"""
    print("\n=== 测试健康检查 ===")
    response = requests.get(f"{BASE_URL}/health")
    print(f"状态码: {response.status_code}")
    print(f"响应: {response.json()}")
    assert response.status_code == 200
    print("✅ 健康检查通过")


def test_root():
    """测试根路径"""
    print("\n=== 测试根路径 ===")
    response = requests.get(f"{BASE_URL}/")
    print(f"状态码: {response.status_code}")
    print(f"响应: {json.dumps(response.json(), ensure_ascii=False, indent=2)}")
    assert response.status_code == 200
    print("✅ 根路径测试通过")


def test_jyutping():
    """测试粤拼标注（不需要 API Key）"""
    print("\n=== 测试粤拼标注 ===")
    data = {
        "text": "你好"
    }
    response = requests.post(f"{BASE_URL}/api/jyutping", json=data)
    print(f"状态码: {response.status_code}")

    if response.status_code == 200:
        result = response.json()
        print(f"原文: {result['original']}")
        print(f"粤拼: {result['jyutping']}")
        print("✅ 粤拼标注测试通过")
    else:
        print(f"❌ 测试失败: {response.text}")


def test_translate():
    """测试翻译（需要 API Key）"""
    print("\n=== 测试翻译 ===")

    if API_KEY == "your-api-key-here":
        print("⚠️  请先在脚本中配置 API_KEY")
        return

    data = {
        "text": "你在干什么？",
        "api_key": API_KEY,
        "model_name": MODEL_NAME,
        "base_url": BASE_API_URL,
        "slang_mode": True
    }

    print(f"发送请求: {data['text']}")
    response = requests.post(f"{BASE_URL}/api/translate", json=data)
    print(f"状态码: {response.status_code}")

    if response.status_code == 200:
        result = response.json()
        print(f"标准粤语: {result['cantonese']}")
        print(f"粤拼: {result['jyutping']}")
        if result.get('slang'):
            print(f"俚语: {result['slang']}")
            print(f"俚语粤拼: {result.get('slang_jyutping', '')}")
        if result.get('note'):
            print(f"注释: {result['note']}")
        print("✅ 翻译测试通过")
    else:
        print(f"❌ 测试失败: {response.text}")


def test_audio():
    """测试语音生成"""
    print("\n=== 测试语音生成 ===")
    data = {
        "text": "你好",
        "voice": "zh-HK-HiuMaanNeural"
    }

    response = requests.post(f"{BASE_URL}/api/audio", json=data)
    print(f"状态码: {response.status_code}")

    if response.status_code == 200:
        result = response.json()
        print(f"音频 URL: {result['audio_url']}")
        print(f"完整访问: {BASE_URL}{result['audio_url']}")
        print("✅ 语音生成测试通过")
    else:
        print(f"❌ 测试失败: {response.text}")


def test_models():
    """测试获取模型列表（需要 API Key）"""
    print("\n=== 测试获取模型列表 ===")

    if API_KEY == "your-api-key-here":
        print("⚠️  请先在脚本中配置 API_KEY")
        return

    data = {
        "api_key": API_KEY,
        "base_url": BASE_API_URL
    }

    response = requests.post(f"{BASE_URL}/api/models", json=data)
    print(f"状态码: {response.status_code}")

    if response.status_code == 200:
        result = response.json()
        models = result['models']
        print(f"找到 {len(models)} 个模型:")
        for model in models[:5]:  # 只显示前5个
            print(f"  - {model}")
        if len(models) > 5:
            print(f"  ... 还有 {len(models) - 5} 个")
        print("✅ 模型列表测试通过")
    else:
        print(f"❌ 测试失败: {response.text}")


def test_explain():
    """测试粤语解释（需要 API Key）"""
    print("\n=== 测试粤语解释 ===")

    if API_KEY == "your-api-key-here":
        print("⚠️  请先在脚本中配置 API_KEY")
        return

    data = {
        "text": "乜嘢",
        "api_key": API_KEY,
        "model_name": MODEL_NAME,
        "base_url": BASE_API_URL
    }

    response = requests.post(f"{BASE_URL}/api/explain", json=data)
    print(f"状态码: {response.status_code}")

    if response.status_code == 200:
        result = response.json()
        print(f"解释: {result['explanation'][:200]}...")  # 只显示前200字
        print("✅ 粤语解释测试通过")
    else:
        print(f"❌ 测试失败: {response.text}")


if __name__ == "__main__":
    print("=" * 60)
    print("粤语学习助手 API 测试")
    print("=" * 60)
    print(f"API 地址: {BASE_URL}")
    print(f"确保后端已启动: python main.py")
    print("=" * 60)

    try:
        # 基础测试（不需要 API Key）
        test_health()
        test_root()
        test_jyutping()
        test_audio()

        # 需要 API Key 的测试
        if API_KEY != "your-api-key-here":
            test_models()
            test_translate()
            test_explain()
        else:
            print("\n⚠️  部分测试跳过：请在脚本中配置 API_KEY 以测试完整功能")

        print("\n" + "=" * 60)
        print("✅ 所有测试完成！")
        print("=" * 60)

    except requests.exceptions.ConnectionError:
        print("\n❌ 连接失败：请确保后端已启动 (python main.py)")
    except Exception as e:
        print(f"\n❌ 测试出错: {e}")
