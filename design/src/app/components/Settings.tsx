import { useNavigate } from 'react-router';
import { useState } from 'react';

export default function Settings() {
  const navigate = useNavigate();
  const [isLoggedIn, setIsLoggedIn] = useState(false);

  return (
    <div className="flex items-center justify-center min-h-screen bg-gray-100">
      {/* iPhone 15 Pro Container */}
      <div className="w-[393px] h-[852px] bg-[#F2F2F7] overflow-hidden shadow-2xl">
        {/* Status Bar */}
        <div className="h-[44px] bg-white flex items-center justify-between px-6 pt-2">
          <span className="text-[15px]">9:41</span>
          <div className="flex items-center gap-1">
            <span className="text-[15px]">􀙇</span>
            <span className="text-[15px]">􀙇</span>
            <span className="text-[15px]">􀙇</span>
          </div>
        </div>

        {/* Navigation Bar */}
        <div className="bg-white px-4 pb-3 border-b border-gray-200">
          <div className="flex items-center justify-between">
            <button
              onClick={() => navigate('/')}
              className="text-[#007AFF] text-[17px] flex items-center gap-1"
            >
              <svg width="13" height="21" viewBox="0 0 13 21" fill="currentColor">
                <path d="M10.5 1.5L2 10.5L10.5 19.5" stroke="currentColor" strokeWidth="2.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
              返回
            </button>
            <h1 className="text-[17px] font-semibold absolute left-1/2 -translate-x-1/2">设置</h1>
          </div>
        </div>

        {/* Scrollable Content */}
        <div className="flex-1 overflow-y-auto px-4 pt-6 pb-8" style={{ height: 'calc(852px - 44px - 60px)' }}>
          {/* API Service Section */}
          <div className="mb-8">
            <h2 className="text-[13px] text-gray-500 px-4 mb-2">API 服务</h2>
            <div className="bg-white rounded-2xl overflow-hidden">
              <div className="p-4">
                <label className="text-[15px] text-gray-900 mb-2 block">服务器地址</label>
                <input
                  type="text"
                  placeholder="http://100.x.x.x:3000"
                  className="w-full text-[15px] text-gray-900 border-none outline-none bg-transparent placeholder:text-gray-400"
                />
              </div>
            </div>
          </div>

          {/* NetEase Account Section */}
          <div>
            <h2 className="text-[13px] text-gray-500 px-4 mb-2">网易云账号</h2>
            
            {!isLoggedIn ? (
              // Not Logged In State
              <div className="bg-white rounded-2xl overflow-hidden p-4">
                <div className="mb-4">
                  <label className="text-[15px] text-gray-900 mb-2 block">手机号</label>
                  <input
                    type="tel"
                    placeholder="请输入手机号"
                    className="w-full bg-[#F2F2F7] rounded-lg p-3 text-[15px] border-none outline-none placeholder:text-gray-400"
                  />
                </div>
                
                <div className="mb-4">
                  <label className="text-[15px] text-gray-900 mb-2 block">验证码</label>
                  <div className="flex gap-2">
                    <input
                      type="text"
                      placeholder="请输入验证码"
                      className="flex-1 bg-[#F2F2F7] rounded-lg p-3 text-[15px] border-none outline-none placeholder:text-gray-400"
                    />
                    <button className="px-4 py-3 bg-[#007AFF] text-white rounded-lg text-[15px] font-semibold whitespace-nowrap">
                      获取验证码
                    </button>
                  </div>
                </div>
                
                <button 
                  onClick={() => setIsLoggedIn(true)}
                  className="w-full bg-[#007AFF] text-white rounded-lg py-3 text-[15px] font-semibold"
                >
                  登录
                </button>
              </div>
            ) : (
              // Logged In State
              <div className="bg-white rounded-2xl overflow-hidden">
                <div className="p-4 flex items-center gap-3 border-b border-gray-200">
                  <img
                    src="https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=80&h=80&fit=crop"
                    alt="User avatar"
                    className="w-[50px] h-[50px] rounded-full object-cover"
                  />
                  <div className="flex-1">
                    <h3 className="text-[17px] font-semibold text-gray-900">音乐爱好者</h3>
                    <p className="text-[13px] text-gray-500">139****8888</p>
                  </div>
                </div>
                
                <button
                  onClick={() => setIsLoggedIn(false)}
                  className="w-full p-4 text-[#FF3B30] text-[15px] font-medium"
                >
                  退出登录
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
