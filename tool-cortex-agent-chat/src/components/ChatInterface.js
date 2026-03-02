import React, { useState, useRef, useEffect } from 'react';
import MessageList from './MessageList';
import MessageInput from './MessageInput';
import ThinkingIndicator from './ThinkingIndicator';
import { sendMessageToAgentStream, createThread } from '../services/snowflakeApi';
import './ChatInterface.css';

const ChatInterface = ({ config }) => {
  const [messages, setMessages] = useState([
    {
      id: 1,
      role: 'assistant',
      content: `Hello! I'm your Snowflake Cortex Agent (${config.agentName || 'Cortex Agent'}). How can I help you today?`,
      timestamp: new Date()
    }
  ]);

  const [isLoading, setIsLoading] = useState(false);
  const [isThinking, setIsThinking] = useState(false);
  const [error, setError] = useState(null);
  const [threadId, setThreadId] = useState(null);
  const [parentMessageId, setParentMessageId] = useState(0);
  const [threadReady, setThreadReady] = useState(false);

  const messagesEndRef = useRef(null);
  const streamAbortRef = useRef(null);
  const streamErrorHandledRef = useRef(false);
  const initializingThreadRef = useRef(false);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  useEffect(() => {
    let cancelled = false;
    const initThread = async () => {
      if (initializingThreadRef.current) return;
      initializingThreadRef.current = true;
      setThreadReady(false);
      setError(null); // Clear any previous errors
      try {
        const id = await createThread();
        if (!cancelled) {
          setThreadId(id);
          setParentMessageId(0);
          setThreadReady(true);
          setError(null);
        }
      } catch (err) {
        if (!cancelled) {
          console.error('Thread initialization failed:', err);
          setError(`Unable to connect to Snowflake agent. ${err.message}`);
          setThreadReady(false);
        }
      } finally {
        initializingThreadRef.current = false;
      }
    };

    initThread();

    return () => {
      cancelled = true;
      if (streamAbortRef.current) {
        streamAbortRef.current.abort();
      }
    };
  }, [config.account, config.user, config.database, config.schema, config.agentName]);

  const addMessage = (message) => {
    setMessages((prev) => [...prev, message]);
  };

  const updateMessageContent = (id, updater) => {
    setMessages((prev) =>
      prev.map((msg) =>
        msg.id === id
          ? {
              ...msg,
              content: typeof updater === 'function' ? updater(msg.content) : updater
            }
          : msg
      )
    );
  };

  const ensureThread = async () => {
    if (threadReady && threadId) return threadId;
    const id = await createThread();
    setThreadId(id);
    setParentMessageId(0);
    setThreadReady(true);
    return id;
  };

  const handleStreamingResponse = async (content) => {
    const userMessage = {
      id: Date.now(),
      role: 'user',
      content: content.trim(),
      timestamp: new Date()
    };

    addMessage(userMessage);
    setIsLoading(true);
    setIsThinking(true);
    setError(null);

    const assistantMessageId = userMessage.id + 1;
    addMessage({
      id: assistantMessageId,
      role: 'assistant',
      content: '',
      timestamp: new Date()
    });

    try {
      const controller = new AbortController();
      streamAbortRef.current = controller;
      streamErrorHandledRef.current = false;

      const currentThreadId = await ensureThread();

      await sendMessageToAgentStream(
        config,
        content.trim(),
        {
          onDelta: (chunk) => {
            setIsThinking(false);
            updateMessageContent(assistantMessageId, (existing) => `${existing || ''}${chunk}`);
          },
          onComplete: (result) => {
            updateMessageContent(assistantMessageId, result.content || '');
            if (result.assistantMessageId) {
              setParentMessageId(result.assistantMessageId);
            }
            streamAbortRef.current = null;
          },
          onError: (streamError) => {
            streamErrorHandledRef.current = true;
            updateMessageContent(
              assistantMessageId,
              `I'm sorry, I encountered an error: ${streamError.message}\n\n💡 Tip: Check the browser console (F12 → Console) for detailed debugging information about the API request.`
            );
            setError(streamError.message);
            streamAbortRef.current = null;
          },
          onMetadata: (meta) => {
            if (meta?.role === 'assistant' && typeof meta.message_id === 'number') {
              setParentMessageId(meta.message_id);
            }
          }
        },
        { signal: controller.signal, threadId: currentThreadId, parentMessageId }
      );
    } catch (err) {
      if (err.name === 'AbortError') {
        updateMessageContent(assistantMessageId, (existing) => existing || '[Request aborted]');
      } else if (!streamErrorHandledRef.current) {
        console.error('Error sending message:', err);
        setError(err.message || 'Failed to send message to the agent');
        updateMessageContent(
          assistantMessageId,
          `I'm sorry, I encountered an error: ${err.message || 'Unknown error occurred'}\n\n💡 Tip: Check the browser console (F12 → Console) for detailed debugging information about the API request.`
        );
      }
    } finally {
      setIsLoading(false);
      setIsThinking(false);
      streamAbortRef.current = null;
    }
  };

  const handleSendMessage = async (content) => {
    if (!content.trim()) return;

    await handleStreamingResponse(content);
  };

  const retryConnection = async () => {
    if (streamAbortRef.current) {
      streamAbortRef.current.abort();
      streamAbortRef.current = null;
    }

    setError(null);
    setThreadReady(false);

    try {
      const id = await createThread();
      setThreadId(id);
      setParentMessageId(0);
      setThreadReady(true);
    } catch (err) {
      console.error('Retry connection failed:', err);
      setError(`Unable to connect to Snowflake agent. ${err.message}`);
      setThreadReady(false);
    }
  };

  const clearChat = () => {
    if (streamAbortRef.current) {
      streamAbortRef.current.abort();
      streamAbortRef.current = null;
    }

    setMessages([
      {
        id: 1,
        role: 'assistant',
        content: `Hello! I'm your Snowflake Cortex Agent (${config.agentName || 'Cortex Agent'}). How can I help you today?`,
        timestamp: new Date()
      }
    ]);
    setError(null);
    setParentMessageId(0);
    setThreadReady(false);
    ensureThread().catch(() => {
      /* handled separately */
    });
  };

  return (
    <div className="chat-interface">
      <div className="chat-header">
        <div className="agent-info">
          <h3>🤖 {config.agentName}</h3>
          <span className="connection-status">
            Connected to {config.database}.{config.schema} {threadReady ? `(thread ${threadId})` : '(starting thread...)'}
          </span>
        </div>
        <button className="clear-button" onClick={clearChat}>
          🗑️ Clear Chat
        </button>
      </div>

      <div className="chat-container">
        <MessageList
          messages={messages}
          isLoading={isLoading}
        />
        {isThinking && <ThinkingIndicator />}
        <div ref={messagesEndRef} />
      </div>

      {error && (
        <div className="error-banner">
          <div className="error-content">
            <span>⚠️ {error}</span>
            {!threadReady && (
              <button className="retry-button" onClick={retryConnection}>
                🔄 Retry Connection
              </button>
            )}
          </div>
          <button className="close-button" onClick={() => setError(null)}>✕</button>
        </div>
      )}

      <MessageInput
        onSendMessage={handleSendMessage}
        isLoading={isLoading}
        isDisabled={!threadReady}
      />
    </div>
  );
};

export default ChatInterface;
