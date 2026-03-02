/**
 * Snowflake Cortex Agent API client (via local backend proxy).
 *
 * The private key never touches the browser. All auth and Snowflake calls
 * happen in the backend proxy at http://localhost:4000 by default.
 */

const backendBase = process.env.REACT_APP_BACKEND_URL || '';

const buildBackendUrl = (path) => `${backendBase}${path}`;

const validateConfig = (config) => {
  const { account, user, database, schema, agentName } = config;

  if (!account || !account.trim()) {
    throw new Error('Snowflake account is required');
  }

  if (!user || !user.trim()) {
    throw new Error('Snowflake user is required');
  }

  if (!database || !database.trim()) {
    throw new Error('Database name is required');
  }

  if (!schema || !schema.trim()) {
    throw new Error('Schema name is required');
  }

  if (!agentName || !agentName.trim()) {
    throw new Error('Agent name is required');
  }
};

const buildHeaders = (accept = 'application/json') => ({
  'Content-Type': 'application/json',
  Accept: accept
});

export const createThread = async (originApplication = 'cortex-chat') => {
  const response = await fetch(buildBackendUrl('/api/threads'), {
    method: 'POST',
    headers: buildHeaders(),
    body: JSON.stringify({ origin_application: originApplication })
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(
      `Failed to create thread (${response.status} ${response.statusText}): ${detail}`
    );
  }

  const data = await response.json();
  return data.thread_id || data.id || data;
};

const extractResponseText = (data) => {
  if (!data || typeof data !== 'object') {
    return null;
  }

  if (typeof data.output === 'string') {
    return data.output;
  }

  if (data.response && typeof data.response.output_text === 'string') {
    return data.response.output_text;
  }

  if (Array.isArray(data.messages)) {
    const assistantMessage = data.messages.find((msg) => msg.role === 'assistant');
    if (assistantMessage) {
      if (Array.isArray(assistantMessage.content)) {
        const textChunk = assistantMessage.content.find(
          (chunk) => chunk.type === 'text' && typeof chunk.text === 'string'
        );
        if (textChunk) {
          return textChunk.text;
        }
      }

      if (typeof assistantMessage.content === 'string') {
        return assistantMessage.content;
      }
    }
  }

  return null;
};

export const sendMessageToAgent = async (config, message, options = {}) => {
  validateConfig(config);

  if (!message || !message.trim()) {
    throw new Error('Cannot send an empty message to the Cortex Agent.');
  }

  const payload = {
    message: message.trim(),
    threadId: options.threadId,
    parentMessageId: options.parentMessageId
  };

  const response = await fetch(buildBackendUrl('/api/agent/run'), {
    method: 'POST',
    headers: buildHeaders(),
    body: JSON.stringify(payload)
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`Backend Error ${response.status} ${response.statusText}: ${errorBody}`);
  }

  const data = await response.json();
  const text = extractResponseText(data) ?? JSON.stringify(data);

  return {
    content: text,
    metadata: data.metadata || {}
  };
};

const parseSSEEvents = (buffer) => {
  const events = [];
  let remainder = buffer.replace(/\r\n/g, '\n');

  while (true) {
    const boundary = remainder.indexOf('\n\n');
    if (boundary === -1) {
      break;
    }

    const rawEvent = remainder.slice(0, boundary).trim();
    remainder = remainder.slice(boundary + 2);

    if (!rawEvent) {
      continue;
    }

    const event = { event: 'message', data: '' };

    rawEvent.split('\n').forEach((line) => {
      if (line.startsWith('event:')) {
        event.event = line.slice(6).trim();
      } else if (line.startsWith('data:')) {
        const value = line.slice(5).trim();
        event.data = event.data ? `${event.data}\n${value}` : value;
      }
    });

    events.push(event);
  }

  return { events, remainder };
};

const extractTextFromEvent = (payload) => {
  if (!payload || typeof payload !== 'object') {
    return '';
  }

  if (typeof payload.text === 'string') {
    return payload.text;
  }

  if (payload.data && typeof payload.data.text === 'string') {
    return payload.data.text;
  }

  if (typeof payload.delta === 'string') {
    return payload.delta;
  }

  if (payload.data && typeof payload.data.delta === 'string') {
    return payload.data.delta;
  }

  return '';
};

const extractMetadataFromEvent = (payload) => {
  if (!payload || typeof payload !== 'object') {
    return undefined;
  }

  if (payload.metadata) {
    return payload.metadata;
  }

  if (payload.data && payload.data.metadata) {
    return payload.data.metadata;
  }

  if (payload.response && payload.response.metadata) {
    return payload.response.metadata;
  }

  return undefined;
};

export const sendMessageToAgentStream = async (config, message, handlers = {}, options = {}) => {
  validateConfig(config);

  if (!message || !message.trim()) {
    throw new Error('Cannot send an empty message to the Cortex Agent.');
  }

  const { onDelta, onComplete, onError } = handlers;
  const { signal, threadId, parentMessageId } = options;

  if (signal?.aborted) {
    throw new DOMException('The request was aborted before it started.', 'AbortError');
  }

  const payload = {
    message: message.trim(),
    threadId,
    parentMessageId
  };

  const response = await fetch(buildBackendUrl('/api/agent/run/stream'), {
    method: 'POST',
    headers: buildHeaders('text/event-stream'),
    body: JSON.stringify(payload),
    signal
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`Backend Error ${response.status} ${response.statusText}: ${errorBody}`);
  }

  if (!response.body) {
    throw new Error('Snowflake API Error: streaming response body was empty.');
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let accumulated = '';
  let completed = false;
  let finalMetadata;
  let latestAssistantMessageId;

  try {
    if (signal) {
      signal.addEventListener(
        'abort',
        () => {
          try {
            reader.cancel();
          } catch (_) {
            /* ignore cancel errors */
          }
        },
        { once: true }
      );
    }

    while (true) {
      const { value, done } = await reader.read();
      if (done) {
        break;
      }

      buffer += decoder.decode(value, { stream: true });
      const { events, remainder } = parseSSEEvents(buffer);
      buffer = remainder;

      for (const { event, data } of events) {
        let parsed;
        try {
          parsed = data ? JSON.parse(data) : {};
        } catch (parseError) {
          const error = new Error(`Failed to parse streaming event payload: ${parseError.message}`);
          if (onError) {
            onError(error);
          }
          throw error;
        }

        if (event === 'response.error' || event === 'error') {
          const errorMessage = parsed?.data?.message || parsed?.message || 'Unknown error from agent.';
          const error = new Error(errorMessage);
          if (onError) {
            onError(error);
          }
          throw error;
        }

        if (event === 'metadata') {
          const meta = parsed?.data || parsed;
          if (meta?.role === 'assistant' && typeof meta.message_id === 'number') {
            latestAssistantMessageId = meta.message_id;
          }
          if (handlers.onMetadata) {
            handlers.onMetadata(meta);
          }
          continue;
        }

        if (event === 'response.text.delta' || event === 'response.output_text.delta' || event === 'response.delta' || event === 'message.delta') {
          const chunk = extractTextFromEvent(parsed);
          if (chunk) {
            accumulated += chunk;
            if (onDelta) {
              onDelta(chunk);
            }
          }
          continue;
        }

        if (event === 'response.text' || event === 'response.output_text') {
          const text = extractTextFromEvent(parsed);
          if (text) {
            accumulated = text;
          }
          finalMetadata = extractMetadataFromEvent(parsed);
          continue;
        }

        if (event === 'response' || event === 'response.completed') {
          const text = extractTextFromEvent(parsed) || accumulated;
          finalMetadata = finalMetadata || extractMetadataFromEvent(parsed);
          completed = true;
          if (onComplete) {
            onComplete({ content: text, metadata: finalMetadata, assistantMessageId: latestAssistantMessageId });
          }
          return { content: text, metadata: finalMetadata, assistantMessageId: latestAssistantMessageId };
        }

        // Ignore other event types (e.g., response.status, response.thinking)
      }
    }

    const finalText = accumulated;
    completed = true;
    if (onComplete) {
      onComplete({ content: finalText, metadata: finalMetadata, assistantMessageId: latestAssistantMessageId });
    }
    return { content: finalText, metadata: finalMetadata, assistantMessageId: latestAssistantMessageId };
  } catch (error) {
    if (error.name === 'AbortError') {
      return { content: accumulated, metadata: finalMetadata, assistantMessageId: latestAssistantMessageId };
    }

    if (onError && !completed) {
      onError(error);
    }
    throw error;
  } finally {
    try {
      reader.releaseLock();
    } catch (_) {
      // Ignore release errors
    }
  }
};

export const describeAgent = async (config) => {
  validateConfig(config);
  throw new Error('describeAgent is not implemented in the backend proxy client.');
};
