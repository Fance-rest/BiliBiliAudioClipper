interface IOSAlertProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  message: string;
  buttons: Array<{
    text: string;
    style?: 'default' | 'destructive' | 'cancel';
    onPress: () => void;
  }>;
}

export default function IOSAlert({ isOpen, onClose, title, message, buttons }: IOSAlertProps) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop with blur */}
      <div 
        className="absolute inset-0 bg-black/30 backdrop-blur-sm"
        onClick={onClose}
      />
      
      {/* Alert Dialog */}
      <div className="relative w-[270px] bg-white/90 backdrop-blur-xl rounded-2xl overflow-hidden shadow-2xl">
        {/* Title and Message */}
        <div className="px-4 pt-5 pb-4 text-center">
          <h2 className="text-[17px] font-semibold text-gray-900 mb-1">
            {title}
          </h2>
          <p className="text-[13px] text-gray-600 leading-relaxed">
            {message}
          </p>
        </div>
        
        {/* Buttons */}
        <div className="border-t border-gray-300/60">
          {buttons.map((button, index) => (
            <div key={index}>
              <button
                onClick={() => {
                  button.onPress();
                  onClose();
                }}
                className={`
                  w-full py-3 text-[17px] transition-colors
                  ${button.style === 'destructive' 
                    ? 'text-[#FF3B30] font-normal' 
                    : button.style === 'cancel'
                    ? 'text-[#007AFF] font-semibold'
                    : 'text-[#007AFF] font-normal'
                  }
                  active:bg-gray-200/50
                  ${index < buttons.length - 1 ? 'border-b border-gray-300/60' : ''}
                `}
              >
                {button.text}
              </button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
