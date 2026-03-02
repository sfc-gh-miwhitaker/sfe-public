import React, { useState, useRef } from 'react';
import './MessageInput.css';

const MessageInput = ({ onSendMessage, isLoading, isDisabled = false }) => {
  const [message, setMessage] = useState('');
  const textareaRef = useRef(null);

  const handleSubmit = (e) => {
    e.preventDefault();
    if (message.trim() && !isLoading && !isDisabled) {
      onSendMessage(message);
      setMessage('');
      if (textareaRef.current) {
        textareaRef.current.style.height = 'auto';
      }
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e);
    }
  };

  const handleChange = (e) => {
    setMessage(e.target.value);

    // Auto-resize textarea
    const textarea = e.target;
    textarea.style.height = 'auto';
    textarea.style.height = Math.min(textarea.scrollHeight, 120) + 'px';
  };

  return (
    <div className="message-input-container">
      <form onSubmit={handleSubmit} className="message-input-form">
        <div className="input-wrapper">
          <textarea
            ref={textareaRef}
            value={message}
            onChange={handleChange}
            onKeyPress={handleKeyPress}
            placeholder="Type your message... (Press Enter to send, Shift+Enter for new line)"
            className="message-textarea"
            disabled={isLoading || isDisabled}
            rows={1}
          />
          <button
            type="submit"
            className={`send-button ${!message.trim() || isLoading || isDisabled ? 'disabled' : ''}`}
            disabled={!message.trim() || isLoading || isDisabled}
          >
            {isLoading ? (
              <div className="loading-spinner"></div>
            ) : (
              '📤'
            )}
          </button>
        </div>
      </form>
    </div>
  );
};

export default MessageInput;
