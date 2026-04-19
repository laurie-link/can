"""
FastAPI 后端主文件
粤语学习助手 API
"""
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pathlib import Path
import os
import asyncio
from typing import Optional

from models.schemas import (
    TranslateRequest, TranslateResponse,
    JyutpingRequest, JyutpingResponse,
    ExplainRequest, ExplainResponse,
    AudioRequest,
    ModelsRequest, ModelsResponse
)
from services.translation import (
    translate_to_cantonese,
    explain_cantonese,
    fetch_available_models
)
from services.jyutping import add_jyutping
from services.audio import generate_audio, cleanup_old_audio_files, list_hk_tts_voices


# 定时清理 TTS 缓存文件的后台协程（在 shutdown 时取消）
_cleanup_audio_task: Optional[asyncio.Task] = None


async def _periodic_audio_cleanup_loop() -> None:
    """按间隔扫描并删除过期的 static/audio/*.mp3。"""
    interval = int(os.environ.get("TTS_AUDIO_CLEANUP_INTERVAL_SEC", "300"))
    while True:
        await asyncio.sleep(interval)
        await asyncio.to_thread(cleanup_old_audio_files)


# 创建 FastAPI 应用
app = FastAPI(
    title="粤语学习助手 API",
    description="提供普通话转粤语、粤语拼音标注、粤语解释、语音生成等功能",
    version="1.0.0"
)

# 配置 CORS（允许所有来源，生产环境应该限制具体域名）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境应改为具体的前端域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 静态目录：相对 main.py 所在目录，避免从 backend/ 启动时路径错到 backend/backend/static
BACKEND_ROOT = Path(__file__).resolve().parent
STATIC_DIR = BACKEND_ROOT / "static"
STATIC_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


@app.get("/")
async def root():
    """API根路径"""
    return {
        "message": "粤语学习助手 API",
        "version": "1.0.0",
        "endpoints": {
            "translate": "/api/translate",
            "jyutping": "/api/jyutping",
            "explain": "/api/explain",
            "audio": "/api/audio",
            "audio_voices": "/api/audio/voices",
            "models": "/api/models"
        }
    }


@app.get("/health")
async def health_check():
    """健康检查"""
    return {"status": "ok"}


@app.post("/api/models", response_model=ModelsResponse)
async def get_models(request: ModelsRequest):
    """
    获取可用模型列表

    Args:
        request: 包含 API Key 和 Base URL 的请求

    Returns:
        可用模型列表
    """
    try:
        models = fetch_available_models(request.base_url, request.api_key)
        return ModelsResponse(models=models)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/translate", response_model=TranslateResponse)
async def translate(request: TranslateRequest):
    """
    普通话转粤语翻译

    Args:
        request: 包含待翻译文本、API配置等信息的请求

    Returns:
        包含粤语翻译、粤拼标注、俚语版本等信息的响应
    """
    try:
        # 调用翻译服务
        result = translate_to_cantonese(
            text=request.text,
            api_key=request.api_key,
            model_name=request.model_name,
            base_url=request.base_url,
            slang_mode=request.slang_mode
        )

        # 粤拼一律由本机 PyCantonese 服务生成，不采用模型输出的粤拼
        cantonese = result.get("cantonese", "")
        if cantonese:
            result["jyutping"] = add_jyutping(cantonese)
        else:
            result["jyutping"] = ""

        slang = result.get("slang")
        if slang:
            result["slang_jyutping"] = add_jyutping(slang)
        else:
            result["slang_jyutping"] = None

        return TranslateResponse(
            cantonese=result.get("cantonese", ""),
            jyutping=result.get("jyutping", ""),
            slang=result.get("slang"),
            slang_jyutping=result.get("slang_jyutping"),
            note=result.get("note")
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/jyutping", response_model=JyutpingResponse)
async def annotate_jyutping(request: JyutpingRequest):
    """
    粤语拼音标注

    Args:
        request: 包含待标注粤语文本的请求

    Returns:
        包含原始文本和粤拼标注结果的响应
    """
    try:
        jyutping_result = add_jyutping(request.text)
        return JyutpingResponse(
            original=request.text,
            jyutping=jyutping_result
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/explain", response_model=ExplainResponse)
async def explain(request: ExplainRequest):
    """
    粤语解释

    Args:
        request: 包含待解释粤语文本、API配置等信息的请求

    Returns:
        包含AI生成解释的响应
    """
    try:
        explanation = explain_cantonese(
            text=request.text,
            api_key=request.api_key,
            model_name=request.model_name,
            base_url=request.base_url
        )
        return ExplainResponse(explanation=explanation)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/audio/voices")
async def get_tts_voices():
    """
    列出 Edge-TTS 中可用的香港粤语相关音色（供客户端选择 voice 参数）。
    """
    try:
        voices = await list_hk_tts_voices()
        return {"voices": voices}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/audio")
async def generate_audio_endpoint(
    request: AudioRequest,
    background_tasks: BackgroundTasks
):
    """
    语音生成

    Args:
        request: 包含待转换文本和语音选择的请求
        background_tasks: 后台任务，用于定期清理旧音频文件

    Returns:
        包含音频文件URL的响应
    """
    try:
        # 生成语音文件（异步调用）
        audio_path = await generate_audio(request.text, request.voice)

        # 转换为相对路径（相对于 static 目录）
        audio_path = Path(audio_path)
        relative_path = audio_path.relative_to(STATIC_DIR)

        # 返回可访问的URL
        audio_url = f"/static/{relative_path.as_posix()}"

        # 每次生成后顺带清理过期文件（保留时间见 TTS_AUDIO_MAX_AGE_SECONDS）
        background_tasks.add_task(cleanup_old_audio_files)

        return {
            "audio_url": audio_url,
            "message": "语音生成成功"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.on_event("startup")
async def startup_event():
    """应用启动时执行"""
    global _cleanup_audio_task
    print("粤语学习助手 API 启动成功")
    print("API 文档：http://localhost:6783/docs")
    # 启动时清一批过期文件，并启动定时清理（不依赖是否有人请求 /api/audio）
    n = cleanup_old_audio_files()
    if n:
        print(f"启动时已清理过期 TTS 文件 {n} 个")
    _cleanup_audio_task = asyncio.create_task(_periodic_audio_cleanup_loop())


@app.on_event("shutdown")
async def shutdown_event():
    """应用关闭时执行"""
    global _cleanup_audio_task
    print("粤语学习助手 API 关闭")
    if _cleanup_audio_task is not None:
        _cleanup_audio_task.cancel()
        try:
            await _cleanup_audio_task
        except asyncio.CancelledError:
            pass
        _cleanup_audio_task = None


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=6783,
        reload=True,  # 开发模式启用热重载
        log_level="info"
    )
