import { useState, useCallback, useRef } from 'react';
import type { AgentContext, ChatMessage, ThinkingStep } from '../types';

const API_BASE = '/api';

function addThinkingStep(
  steps: ThinkingStep[],
  type: ThinkingStep['type'],
  text: string,
): ThinkingStep[] {
  const last = steps[steps.length - 1];
  if (last?.type === type && type === 'thinking') {
    return [...steps.slice(0, -1), { ...last, text: last.text + text }];
  }
  return [...steps, { type, text, timestamp: new Date() }];
}

function updateAssistantMessage(
  prev: ChatMessage[],
  content: string,
  thinkingSteps: ThinkingStep[],
): ChatMessage[] {
  const last = prev[prev.length - 1];
  if (last?.role === 'assistant') {
    return [
      ...prev.slice(0, -1),
      { ...last, content, thinkingSteps },
    ];
  }
  return [...prev, { role: 'assistant', content, timestamp: new Date(), thinkingSteps }];
}

export function useAgentChat() {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [threadId, setThreadId] = useState<string | null>(null);
  const parentMessageIdRef = useRef(0);

  const resetChat = useCallback(() => {
    setMessages([]);
    setThreadId(null);
    setError(null);
    parentMessageIdRef.current = 0;
  }, []);

  const sendMessage = useCallback(async (message: string, ctx: AgentContext) => {
    setIsLoading(true);
    setError(null);

    const userMsg: ChatMessage = { role: 'user', content: message, timestamp: new Date() };
    setMessages(prev => [...prev, userMsg]);

    try {
      let currentThreadId = threadId;
      if (!currentThreadId) {
        const threadRes = await fetch(`${API_BASE}/agent/thread`, { method: 'POST' });
        if (!threadRes.ok) throw new Error('Failed to create thread');
        const threadData = await threadRes.json();
        currentThreadId = threadData.id;
        setThreadId(currentThreadId);
      }

      const response = await fetch(`${API_BASE}/agent/run`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...ctx,
          message,
          threadId: currentThreadId,
          parentMessageId: parentMessageIdRef.current,
        }),
      });

      if (!response.ok) {
        const errText = await response.text();
        throw new Error(`API error ${response.status}: ${errText}`);
      }

      const reader = response.body?.getReader();
      if (!reader) throw new Error('No response stream');

      const decoder = new TextDecoder();
      let assistantContent = '';
      let thinkingSteps: ThinkingStep[] = [];
      let currentEvent = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const chunk = decoder.decode(value);
        const lines = chunk.split('\n');

        for (const line of lines) {
          if (line.startsWith('event:')) {
            currentEvent = line.split(':', 2)[1].trim();
          } else if (line.startsWith('data:')) {
            const data = line.slice(5).trim();
            try {
              const eventData = JSON.parse(data);

              switch (currentEvent) {
                case 'response.status':
                  thinkingSteps = addThinkingStep(thinkingSteps, 'status', eventData.message);
                  setMessages(prev => updateAssistantMessage(prev, assistantContent, thinkingSteps));
                  break;

                case 'response.thinking.delta':
                  thinkingSteps = addThinkingStep(thinkingSteps, 'thinking', eventData.text || '');
                  setMessages(prev => updateAssistantMessage(prev, assistantContent, thinkingSteps));
                  break;

                case 'response.tool_use':
                  thinkingSteps = addThinkingStep(
                    thinkingSteps,
                    'tool_use',
                    `Using ${eventData.name ?? eventData.type}`,
                  );
                  setMessages(prev => updateAssistantMessage(prev, assistantContent, thinkingSteps));
                  break;

                case 'response.tool_result.status':
                  thinkingSteps = addThinkingStep(thinkingSteps, 'tool_status', eventData.message);
                  setMessages(prev => updateAssistantMessage(prev, assistantContent, thinkingSteps));
                  break;

                case 'response.tool_result.analyst.delta': {
                  const think = eventData.delta?.think;
                  if (think) {
                    thinkingSteps = addThinkingStep(thinkingSteps, 'thinking', think);
                    setMessages(prev => updateAssistantMessage(prev, assistantContent, thinkingSteps));
                  }
                  break;
                }

                case 'response.text.delta':
                  assistantContent += eventData.text || '';
                  setMessages(prev => updateAssistantMessage(prev, assistantContent, thinkingSteps));
                  break;

                case 'metadata':
                  if (eventData.metadata?.role === 'assistant') {
                    parentMessageIdRef.current = eventData.metadata.message_id;
                  }
                  break;
              }
            } catch {
              // skip malformed JSON lines
            }
          }
        }
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      setError(msg);
      setMessages(prev => [
        ...prev,
        { role: 'assistant', content: `Error: ${msg}`, timestamp: new Date() },
      ]);
    } finally {
      setIsLoading(false);
    }
  }, [threadId]);

  return { messages, isLoading, error, threadId, sendMessage, resetChat };
}
