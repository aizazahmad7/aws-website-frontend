from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List, Dict, Any, Literal

Role = Literal["user", "assistant", "system"]

class ChatMessage(BaseModel):
    role: Role = Field(description='One of "user", "assistant", or "system"')
    content: str = Field(min_length=1, description="Plain text message")

class ChatRequest(BaseModel):
    # allow fields starting with model_*
    model_config = ConfigDict(protected_namespaces=())

    model_id: str = Field(
        description='Bedrock model id, e.g. "anthropic.claude-3-5-sonnet-20240620-v1:0"'
    )
    messages: List[ChatMessage]
    max_tokens: int = 512
    temperature: float = 0.5
    system: Optional[str] = None

class ChatResponse(BaseModel):
    output_text: str
    usage: Optional[Dict[str, Any]] = None
