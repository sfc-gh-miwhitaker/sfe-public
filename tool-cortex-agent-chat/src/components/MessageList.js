import React from 'react';
import Message from './Message';
import './MessageList.css';

const MessageList = ({ messages, isLoading }) => {
  return (
    <div className="message-list">
      {messages.map(message => (
        <Message
          key={message.id}
          message={message}
        />
      ))}
      {isLoading && (
        <div className="loading-message">
          <div className="message assistant-message">
            <div className="message-content">
              <div className="typing-indicator">
                <span></span>
                <span></span>
                <span></span>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default MessageList;
