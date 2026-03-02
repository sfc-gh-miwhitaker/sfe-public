import React from 'react';
import './Message.css';

const Message = ({ message }) => {
  const formatTime = (timestamp) => {
    return new Date(timestamp).toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const formatContent = (content) => {
    // Simple formatting for code blocks and line breaks
    return content.split('\n').map((line, index) => (
      <React.Fragment key={index}>
        {line}
        {index < content.split('\n').length - 1 && <br />}
      </React.Fragment>
    ));
  };

  return (
    <div className={`message ${message.role}-message ${message.isError ? 'error-message' : ''}`}>
      <div className="message-avatar">
        {message.role === 'user' ? '👤' : '🤖'}
      </div>
      <div className="message-content">
        <div className="message-text">
          {formatContent(message.content)}
        </div>
        <div className="message-timestamp">
          {formatTime(message.timestamp)}
        </div>
      </div>
    </div>
  );
};

export default Message;
