'use client'

import { ConnectButton } from "@rainbow-me/rainbowkit";
import './App.css'; // 导入CSS文件

function App() {
    return (
        <div className="app-container">
            <div className="header">
                <h1 className="title">欢迎来到质押收益合约</h1>
                <p className="subtitle">
                    安全、高效的数字资产质押平台
                    <br />
                    连接钱包，开始您的收益之旅
                </p>
            </div>

            <div className="connect-section">
                <div className="connect-button-wrapper">
                    <ConnectButton />
                </div>
            </div>

            {/* 可以添加更多内容 */}
            <div className="features" style={{marginTop: '40px', color: 'white', textAlign: 'center'}}>
                <p>✨ 高收益回报 | 🔒 安全可靠 | ⚡ 快速交易</p>
            </div>
        </div>
    )
}

export default App