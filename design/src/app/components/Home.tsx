import { useNavigate } from 'react-router';
import { useState } from 'react';
import IOSAlert from './IOSAlert';

export default function Home() {
  const navigate = useNavigate();
  const [showUploadAlert, setShowUploadAlert] = useState(false);

  return (
    <div className="flex items-center justify-center min-h-screen bg-gray-100">
      {/* iPhone 15 Pro Container */}
      <div className="w-[393px] h-[852px] bg-white overflow-hidden shadow-2xl">
        {/* Status Bar */}
        <div className="h-[44px] flex items-center justify-between px-6 pt-2">
          <span className="text-[15px]">9:41</span>
          <div className="flex items-center gap-1">
            <span className="text-[15px]">􀙇</span>
            <span className="text-[15px]">􀙇</span>
            <span className="text-[15px]">􀙇</span>
          </div>
        </div>

        {/* Navigation Bar */}
        <div className="px-4 pb-2">
          <div className="flex items-center justify-between">
            <h1 className="text-[34px] font-bold tracking-tight">音频提取</h1>
            <button 
              onClick={() => navigate('/settings')}
              className="text-[28px] w-10 h-10 flex items-center justify-center"
            >
              ⚙
            </button>
          </div>
        </div>

        {/* Scrollable Content */}
        <div className="flex-1 overflow-y-auto px-4 pb-8" style={{ height: 'calc(852px - 44px - 80px)' }}>
          {/* Video Link Card */}
          <div className="mb-4 bg-[#F2F2F7] rounded-2xl p-4">
            <h2 className="text-[17px] font-semibold mb-3">视频链接</h2>
            <input
              type="text"
              placeholder="粘贴B站链接或BV号"
              className="w-full bg-white rounded-xl p-4 mb-3 text-[15px] border-none outline-none placeholder:text-gray-400"
            />
            <button className="w-full bg-[#007AFF] text-white rounded-xl py-3 text-[15px] font-semibold mb-4">
              解析
            </button>
            
            {/* Result Area */}
            <div className="bg-white rounded-xl p-4 mb-3">
              <div className="flex gap-3 mb-4">
                <img
                  src="https://images.unsplash.com/photo-1611162617474-5b21e879e113?w=120&h=90&fit=crop"
                  alt="Video thumbnail"
                  className="w-[100px] h-[75px] rounded-lg object-cover flex-shrink-0"
                />
                <div className="flex-1 min-w-0">
                  <h3 className="text-[15px] font-semibold mb-1 line-clamp-2">
                    【音乐推荐】精选纯音乐合集 | 适合工作学习
                  </h3>
                  <p className="text-[13px] text-gray-500">10:24</p>
                </div>
              </div>
              
              <button className="w-full bg-[#007AFF] text-white rounded-xl py-3 text-[15px] font-semibold mb-3">
                下载音频
              </button>
              
              {/* Progress Bar - hidden by default, can be shown */}
              <div className="hidden">
                <div className="w-full h-1 bg-gray-200 rounded-full overflow-hidden">
                  <div className="h-full bg-[#007AFF] rounded-full" style={{ width: '45%' }}></div>
                </div>
                <p className="text-[13px] text-gray-500 text-center mt-2">下载中... 45%</p>
              </div>
            </div>
          </div>

          {/* Audio Trimming Card */}
          <div className="mb-4 bg-[#F2F2F7] rounded-2xl p-4">
            <h2 className="text-[17px] font-semibold mb-3">音频裁剪</h2>
            
            {/* Audio Player */}
            <div className="bg-white rounded-xl p-4 mb-3">
              {/* Progress Bar */}
              <div className="mb-3">
                <div className="w-full h-1 bg-gray-200 rounded-full overflow-hidden mb-2">
                  <div className="h-full bg-[#007AFF] rounded-full" style={{ width: '35%' }}></div>
                </div>
                <div className="flex justify-between text-[13px] text-gray-500">
                  <span>1:24</span>
                  <span>3:58</span>
                </div>
              </div>
              
              {/* Play/Pause Button */}
              <div className="flex justify-center">
                <button className="w-12 h-12 rounded-full border-2 border-[#007AFF] flex items-center justify-center text-[#007AFF]">
                  <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
                    <path d="M3 2.5v11l10-5.5L3 2.5z" />
                  </svg>
                </button>
              </div>
            </div>
            
            {/* Time Input Section */}
            <div className="bg-white rounded-xl p-4 mb-3">
              {/* Start Time */}
              <div className="flex items-center gap-3 mb-4">
                <span className="text-[15px] w-12">开始</span>
                <div className="flex items-center gap-1 flex-1">
                  <input
                    type="number"
                    placeholder="分"
                    className="w-16 bg-[#F2F2F7] rounded-lg p-2 text-[15px] text-center border-none outline-none placeholder:text-gray-400"
                    min="0"
                  />
                  <span className="text-[15px] text-gray-500">:</span>
                  <input
                    type="number"
                    placeholder="秒"
                    className="w-16 bg-[#F2F2F7] rounded-lg p-2 text-[15px] text-center border-none outline-none placeholder:text-gray-400"
                    min="0"
                    max="59"
                  />
                </div>
                <button className="px-3 py-1.5 bg-[#E5F1FF] text-[#007AFF] rounded-full text-[13px] font-medium whitespace-nowrap">
                  标记起点
                </button>
              </div>
              
              {/* End Time */}
              <div className="flex items-center gap-3">
                <span className="text-[15px] w-12">结束</span>
                <div className="flex items-center gap-1 flex-1">
                  <input
                    type="number"
                    placeholder="分"
                    className="w-16 bg-[#F2F2F7] rounded-lg p-2 text-[15px] text-center border-none outline-none placeholder:text-gray-400"
                    min="0"
                  />
                  <span className="text-[15px] text-gray-500">:</span>
                  <input
                    type="number"
                    placeholder="秒"
                    className="w-16 bg-[#F2F2F7] rounded-lg p-2 text-[15px] text-center border-none outline-none placeholder:text-gray-400"
                    min="0"
                    max="59"
                  />
                </div>
                <button className="px-3 py-1.5 bg-[#E5F1FF] text-[#007AFF] rounded-full text-[13px] font-medium whitespace-nowrap">
                  标记终点
                </button>
              </div>
            </div>
            
            {/* Trim Button */}
            <button className="w-full border-2 border-[#007AFF] text-[#007AFF] rounded-xl py-3 text-[15px] font-semibold bg-white">
              裁剪
            </button>
          </div>

          {/* Upload Card */}
          <div className="mb-4 bg-[#F2F2F7] rounded-2xl p-4">
            <h2 className="text-[17px] font-semibold mb-3">上传</h2>
            
            {/* File Name Input */}
            <div className="bg-white rounded-xl p-4 mb-3 flex items-center gap-2">
              <input
                type="text"
                defaultValue="周杰伦-晴天-副歌部分"
                className="flex-1 text-[15px] border-none outline-none bg-transparent"
              />
              <span className="text-[15px] text-gray-400">.m4a</span>
            </div>
            
            {/* Upload Button */}
            <button className="w-full bg-[#34C759] text-white rounded-xl py-3 text-[15px] font-semibold mb-3 flex items-center justify-center gap-2" onClick={() => setShowUploadAlert(true)}>
              <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M9 12V3M9 3L6 6M9 3L12 6" strokeLinecap="round" strokeLinejoin="round"/>
                <path d="M15 15H3C2.44772 15 2 14.5523 2 14V10" strokeLinecap="round"/>
              </svg>
              上传到网易云盘
            </button>
            
            {/* Upload Progress Bar - hidden by default */}
            <div className="hidden">
              <div className="w-full h-1 bg-gray-200 rounded-full overflow-hidden">
                <div className="h-full bg-[#34C759] rounded-full" style={{ width: '60%' }}></div>
              </div>
              <p className="text-[13px] text-gray-500 text-center mt-2">上传中... 60%</p>
            </div>
          </div>

          {/* Quality Settings Card */}
          <div className="mb-4 bg-[#F2F2F7] rounded-2xl p-4">
            <h2 className="text-[17px] font-semibold mb-3">音频质量</h2>
            <div className="bg-white rounded-xl overflow-hidden">
              <button className="w-full flex items-center justify-between p-4 border-b border-gray-200">
                <div className="flex flex-col items-start">
                  <span className="text-[15px]">标准</span>
                  <span className="text-[13px] text-gray-500">128 kbps</span>
                </div>
              </button>
              <button className="w-full flex items-center justify-between p-4 border-b border-gray-200">
                <div className="flex flex-col items-start">
                  <span className="text-[15px]">高质量</span>
                  <span className="text-[13px] text-gray-500">256 kbps</span>
                </div>
                <span className="text-[#007AFF] text-[20px]">✓</span>
              </button>
              <button className="w-full flex items-center justify-between p-4">
                <div className="flex flex-col items-start">
                  <span className="text-[15px]">无损</span>
                  <span className="text-[13px] text-gray-500">320 kbps</span>
                </div>
              </button>
            </div>
          </div>

          {/* Advanced Options Card */}
          <div className="mb-4 bg-[#F2F2F7] rounded-2xl p-4">
            <h2 className="text-[17px] font-semibold mb-3">高级选项</h2>
            <div className="bg-white rounded-xl overflow-hidden">
              <div className="flex items-center justify-between p-4 border-b border-gray-200">
                <span className="text-[15px]">保留元数据</span>
                <div className="w-[51px] h-[31px] bg-[#007AFF] rounded-full p-[2px] flex items-center justify-end">
                  <div className="w-[27px] h-[27px] bg-white rounded-full"></div>
                </div>
              </div>
              <div className="flex items-center justify-between p-4 border-b border-gray-200">
                <span className="text-[15px]">标准化音量</span>
                <div className="w-[51px] h-[31px] bg-gray-300 rounded-full p-[2px] flex items-center">
                  <div className="w-[27px] h-[27px] bg-white rounded-full"></div>
                </div>
              </div>
              <div className="flex items-center justify-between p-4">
                <span className="text-[15px]">移除静音片段</span>
                <div className="w-[51px] h-[31px] bg-gray-300 rounded-full p-[2px] flex items-center">
                  <div className="w-[27px] h-[27px] bg-white rounded-full"></div>
                </div>
              </div>
            </div>
          </div>

          {/* Extract Button */}
          <button className="w-full bg-[#007AFF] text-white rounded-2xl py-4 text-[17px] font-semibold mb-4">
            提取音频
          </button>

          <p className="text-[13px] text-gray-500 text-center">
            提取完成后文件将保存到下载文件夹
          </p>
        </div>
      </div>

      {/* iOS Alert */}
      <IOSAlert
        isOpen={showUploadAlert}
        onClose={() => setShowUploadAlert(false)}
        title="上传成功"
        message="音频已上传到网易云盘"
        buttons={[
          {
            text: '保留本地文件',
            style: 'default',
            onPress: () => console.log('Keep local file'),
          },
          {
            text: '删除本地文件',
            style: 'destructive',
            onPress: () => console.log('Delete local file'),
          },
        ]}
      />
    </div>
  );
}