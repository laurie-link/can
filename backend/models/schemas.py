"""
数据模型定义
"""
from pydantic import BaseModel, Field
from typing import Optional


class TranslateRequest(BaseModel):
    """翻译请求"""
    text: str = Field(..., description="要翻译的普通话文本")
    api_key: str = Field(..., description="API Key")
    model_name: str = Field(..., description="模型名称")
    base_url: str = Field(default="https://api.siliconflow.cn/v1", description="API Base URL")
    slang_mode: bool = Field(default=False, description="是否启用俚语模式")


class TranslateResponse(BaseModel):
    """翻译响应"""
    cantonese: str = Field(..., description="标准粤语翻译")
    jyutping: str = Field(..., description="粤拼标注")
    slang: Optional[str] = Field(None, description="俚语版本（如果有）")
    slang_jyutping: Optional[str] = Field(None, description="俚语版粤拼（如果有）")
    note: Optional[str] = Field(None, description="文化注释")


class JyutpingRequest(BaseModel):
    """粤拼标注请求"""
    text: str = Field(..., description="要标注的粤语文本")


class JyutpingResponse(BaseModel):
    """粤拼标注响应"""
    original: str = Field(..., description="原始文本")
    jyutping: str = Field(..., description="粤拼标注结果")


class ExplainRequest(BaseModel):
    """粤语解释请求"""
    text: str = Field(..., description="要解释的粤语内容")
    api_key: str = Field(..., description="API Key")
    model_name: str = Field(..., description="模型名称")
    base_url: str = Field(default="https://api.siliconflow.cn/v1", description="API Base URL")


class ExplainResponse(BaseModel):
    """粤语解释响应"""
    explanation: str = Field(..., description="AI生成的解释")


class AudioRequest(BaseModel):
    """语音生成请求"""
    text: str = Field(..., description="要转换为语音的文本")
    voice: str = Field(default="zh-HK-HiuMaanNeural", description="语音选择")


class ModelsRequest(BaseModel):
    """获取模型列表请求"""
    api_key: str = Field(..., description="API Key")
    base_url: str = Field(default="https://api.siliconflow.cn/v1", description="API Base URL")


class ModelsResponse(BaseModel):
    """获取模型列表响应"""
    models: list[str] = Field(..., description="可用模型列表")
