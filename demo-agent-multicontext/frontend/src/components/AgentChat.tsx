import { useState, useRef, useEffect } from 'react';
import type { ChatMessage, AgentContext, Station, ThinkingStep } from '../types';
import { getStation } from '../utils/buildAgentPayload';

interface AgentChatProps {
  messages: ChatMessage[];
  isLoading: boolean;
  error: string | null;
  context: AgentContext;
  onSend: (message: string) => void;
  onReset: () => void;
}

const EXAMPLE_QUESTIONS: Record<string, string[]> = {
  anonymous: [
    'How do I watch on the PBS app?',
    'What is PBS Passport?',
    'What programs are on tonight?',
  ],
  low: [
    'What were the top rated shows this week?',
    'Which programs had the most streaming starts?',
    'How do I enable closed captions?',
  ],
  full: [
    'Show me viewership metrics for all premiere episodes',
    'What is the average rating by genre?',
    'How many active members does our station have?',
  ],
};

const STEP_ICONS: Record<ThinkingStep['type'], string> = {
  status: '◆',
  thinking: '◇',
  tool_use: '⚙',
  tool_status: '↻',
};

function ThinkingStepsView({ steps, isStreaming }: { steps: ThinkingStep[]; isStreaming: boolean }) {
  const [expanded, setExpanded] = useState(false);
  if (!steps.length) return null;

  const lastStep = steps[steps.length - 1];
  const showExpanded = expanded || isStreaming;

  return (
    <div className="thinking-steps">
      <button
        className="thinking-toggle"
        onClick={() => setExpanded(e => !e)}
      >
        <span className={`thinking-indicator ${isStreaming ? 'pulse' : ''}`}>
          {STEP_ICONS[lastStep.type]}
        </span>
        {isStreaming ? lastStep.text : `${steps.length} step${steps.length > 1 ? 's' : ''}`}
        <span className="thinking-chevron">{showExpanded ? '▾' : '▸'}</span>
      </button>
      {showExpanded && (
        <ul className="thinking-list">
          {steps.map((step, i) => (
            <li key={i} className={`thinking-step thinking-step--${step.type}`}>
              <span className="thinking-step-icon">{STEP_ICONS[step.type]}</span>
              <span className="thinking-step-text">{step.text}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

export function AgentChat({ messages, isLoading, error, context, onSend, onReset }: AgentChatProps) {
  const [input, setInput] = useState('');
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const station: Station = getStation(context.stationId);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim() || isLoading) return;
    onSend(input.trim());
    setInput('');
  };

  const examples = EXAMPLE_QUESTIONS[context.userType] ?? EXAMPLE_QUESTIONS.anonymous;

  return (
    <div className="chat-panel">
      <div className="chat-header" style={{ '--accent': context.userType === 'full' ? '#7c3aed' : context.userType === 'low' ? '#2563eb' : '#6b7280' } as React.CSSProperties}>
        <div className="chat-header-left">
          <strong>{station.callSign} Support Agent</strong>
          <span className="chat-header-sub">
            {context.userType === 'anonymous' ? 'Guest' : context.userName ?? 'User'}
            {' -- '}
            {context.userType === 'anonymous' ? 'Not logged in' : context.userType === 'low' ? 'Basic Member' : 'Station Admin'}
          </span>
        </div>
        <button className="reset-btn" onClick={onReset} title="New conversation">
          New Chat
        </button>
      </div>

      <div className="messages-container">
        {messages.length === 0 && (
          <div className="empty-state">
            <h3>Welcome to {station.name}</h3>
            <p>Ask a question to get started. Try one of these:</p>
            <div className="example-queries">
              {examples.map((q, i) => (
                <button key={i} className="example-btn" onClick={() => onSend(q)}>
                  {q}
                </button>
              ))}
            </div>
          </div>
        )}

        {messages.map((msg, idx) => (
          <div key={idx} className={`message ${msg.role}`}>
            <div className="message-meta">
              <strong>{msg.role === 'user' ? 'You' : `${station.callSign} Agent`}</strong>
              <span className="message-time">{msg.timestamp.toLocaleTimeString()}</span>
            </div>
            {msg.role === 'assistant' && msg.thinkingSteps && msg.thinkingSteps.length > 0 && (
              <ThinkingStepsView
                steps={msg.thinkingSteps}
                isStreaming={isLoading && idx === messages.length - 1}
              />
            )}
            <div className="message-body">{msg.content}</div>
          </div>
        ))}

        {isLoading && messages[messages.length - 1]?.role !== 'assistant' && (
          <div className="message assistant">
            <div className="message-meta"><strong>{station.callSign} Agent</strong></div>
            <div className="message-body typing">
              <span /><span /><span />
            </div>
          </div>
        )}

        {error && !messages.some(m => m.content.startsWith('Error:')) && (
          <div className="error-banner">{error}</div>
        )}

        <div ref={bottomRef} />
      </div>

      <form className="chat-input-form" onSubmit={handleSubmit}>
        <input
          type="text"
          value={input}
          onChange={e => setInput(e.target.value)}
          placeholder={`Ask the ${station.callSign} agent...`}
          disabled={isLoading}
          className="chat-input"
        />
        <button type="submit" disabled={isLoading || !input.trim()} className="send-btn">
          {isLoading ? 'Sending...' : 'Send'}
        </button>
      </form>
    </div>
  );
}
