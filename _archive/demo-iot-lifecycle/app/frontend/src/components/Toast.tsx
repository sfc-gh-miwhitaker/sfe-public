interface Props {
  messages: string[];
}

export default function Toast({ messages }: Props) {
  if (messages.length === 0) return null;

  return (
    <div className="fixed bottom-4 right-4 flex flex-col gap-2 z-50 pointer-events-none">
      {messages.map((msg, i) => (
        <div
          key={`${msg}-${i}`}
          className="px-4 py-2.5 rounded-lg bg-gray-800/95 border border-gray-700/50 text-sm text-gray-200 shadow-xl backdrop-blur-sm animate-slide-up"
        >
          <span className="text-green-400 mr-2 font-bold">&#x25CF;</span>
          {msg}
        </div>
      ))}
    </div>
  );
}
