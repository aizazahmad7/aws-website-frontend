import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from mangum import Mangum

from backend.app.models import ChatRequest, ChatResponse
from backend.app.bedrock_client import invoke_anthropic


app = FastAPI(title="Bedrock FastAPI Backend", version="0.1.0")

# CORS: set to your CloudFront domain later via env
frontend_origin = os.getenv("FRONTEND_ORIGIN", "*")
allow_origins = [frontend_origin] if frontend_origin != "*" else ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/healthz")
def health():
    return {"status": "ok"}

@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    try:
        result = invoke_anthropic(
            model_id=req.model_id,
            messages=[m.model_dump() for m in req.messages],
            max_tokens=req.max_tokens,
            temperature=req.temperature,
            system=req.system,
            region=os.getenv("BEDROCK_REGION"),  # set by Terraform in Lambda; set locally for dev
        )
        return ChatResponse(output_text=result["text"], usage=result.get("usage"))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Expose handler for AWS Lambda
handler = Mangum(app)
