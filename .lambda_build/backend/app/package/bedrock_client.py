import json
import boto3
from typing import List, Dict, Any, Optional

def _runtime(region: Optional[str] = None):
    # Lambda will infer region; locally, set AWS_REGION or pass a region.
    return boto3.client("bedrock-runtime", region_name=region)

def _to_anthropic_messages(messages: List[Dict[str, str]]) -> List[Dict[str, Any]]:
    """
    Convert generic messages [{'role':'user','content':'...'}, ...]
    into Anthropic Bedrock format:
    [{"role":"user","content":[{"type":"text","text":"..."}]}, ...]
    """
    out: List[Dict[str, Any]] = []
    for m in messages:
        out.append({
            "role": m["role"],
            "content": [{"type": "text", "text": m["content"]}],
        })
    return out

def invoke_anthropic(
    model_id: str,
    messages: List[Dict[str, str]],
    max_tokens: int,
    temperature: float,
    system: Optional[str] = None,
    region: Optional[str] = None,
) -> Dict[str, Any]:
    client = _runtime(region)

    body: Dict[str, Any] = {
        "messages": _to_anthropic_messages(messages),
        "max_tokens": max_tokens,
        "temperature": temperature,
    }
    if system:
        body["system"] = [{"type": "text", "text": system}]

    resp = client.invoke_model(
        modelId=model_id,
        body=json.dumps(body),
        accept="application/json",
        contentType="application/json",
    )
    payload = json.loads(resp["body"].read())

    # Anthropic responses have "content": [{"type":"text","text":"..."}...]
    text_parts: List[str] = []
    for part in payload.get("content", []):
        if isinstance(part, dict) and part.get("type") == "text":
            text_parts.append(part.get("text", ""))

    return {
        "text": "".join(text_parts) or payload.get("output_text", "") or "",
        "usage": payload.get("usage", {}),
    }
