import { useEffect, useState } from "react";
import "./App.css";

const API_BASE_URL = process.env.REACT_APP_API_BASE_URL || "http://localhost:8000";


export default function App() {
  const [status, setStatus] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function load() {
      try {
        const res = await fetch(`${API_BASE_URL}/healthz`);
        if (!res.ok) throw new Error(`${res.status} ${await res.text()}`);
        const json = await res.json();
        setStatus(json.status || "ok");
      } catch (e) {
        setError(e.message);
      }
    }
    load();
  }, []);

  return (
    <div className="App">
      <header className="App-header">
        <h1>Frontend ↔ Backend check v2</h1>
        {error ? (
          <p style={{ color: "salmon" }}>Error: {error}</p>
        ) : status ? (
          <p>API health: <strong>{status}</strong></p>
        ) : (
          <p>Checking API…</p>
        )}
        <small>Calling: {API_BASE_URL}/healthz</small>
      </header>
    </div>
  );
}
