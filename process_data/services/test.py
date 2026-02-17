import pandas as pd
from mootdx.quotes import ExtQuotes  # 注意：这里是 ExtQuotes，不是 ExtensionQuotes
import os

# ================= 配置区 =================
SYMBOL = "RB2505"       # 期货合约代码 (螺纹钢)
MARKET_ID = 30          # 30=上期所(SHFE), 28=郑商所, 29=大商所, 47=中金所
K_LINE_TYPE = 1         # 0=5分钟, 1=5分钟(部分版本), 2=10分钟... 建议试 1 或 0
                        # 通达信定义: 0=5min, 1=15min? 不同版本可能有差异
                        # 常用: 0=5分钟, 1=15分钟, 2=30分钟, 3=1小时, 4=日线
                        # 修正：mootdx源码中 category 参数：
                        # 0: 5分钟K线
                        # 1: 5分钟K线 (兼容模式，建议优先试 1)
                        # 4: 15分钟
                        # 7: 1小时
FETCH_COUNT = 800       # 单次获取条数 (最大 800)
CSV_FILENAME = "RB2505_5min.csv"
# =========================================

def fetch_and_save():
    print(f"🚀 正在连接通达信服务器，获取 {SYMBOL} ...")

    # 1. 实例化扩展行情客户端 (期货)
    # 使用 best_ip=True 让它自动找最快的服务器
    client = ExtQuotes(best_ip=True)

    # 2. 发送请求
    # category=1 代表 5分钟线 (具体取决于服务器定义，如果是15分钟，改成0试试)
    data = client.get_instrument_bars(
        category=1,     
        market=MARKET_ID,
        code=SYMBOL,
        start=0,        # 0 表示从最新时间往前推
        count=FETCH_COUNT
    )

    # 3. 校验数据
    if data is None or len(data) == 0:
        print("❌ 获取失败！数据为空。")
        print("可能原因：")
        print("1. 市场ID(MARKET_ID) 不对 (上期所是30)")
        print("2. 合约代码(SYMBOL) 不存在或已过期")
        print("3. 当前网络无法连接通达信服务器")
        return

    print(f"✅ 成功获取 {len(data)} 条原始数据")

    # 4. 转换为 DataFrame
    df = pd.DataFrame(data)

    # 5. 数据清洗：合成 datetime 列
    # 通达信返回的是 year, month, day, hour, minute 分开的列
    try:
        df['datetime'] = pd.to_datetime(df[['year', 'month', 'day', 'hour', 'minute']])
    except Exception as e:
        print(f"⚠️ 时间合成失败，可能是列名不匹配: {e}")
        print("当前列名:", df.columns)
        return

    # 6. 重命名列 (映射到你要求的格式)
    # 原始列名通常是: open, high, low, close, vol, amount, position...
    rename_map = {
        'vol': 'volume',          # 成交量
        'amount': 'amount',       # 成交额
        'position': 'position'    # 持仓量
    }
    df.rename(columns=rename_map, inplace=True)

    # 7. 补充 Symbol 列
    df['symbol'] = SYMBOL

    # 8. 筛选并排序最终列
    # 你要求的格式: datetime, open, high, low, close, volume, amount, position, symbol
    target_cols = ['datetime', 'open', 'high', 'low', 'close', 'volume', 'amount', 'position', 'symbol']
    
    # 防御性编程：只保留存在的列
    final_cols = [c for c in target_cols if c in df.columns]
    df_final = df[final_cols]

    # 9. 按时间正序排列 (旧 -> 新)
    df_final = df_final.sort_values(by='datetime', ascending=True)

    # 10. 导出 CSV
    save_path = os.path.join(os.getcwd(), CSV_FILENAME)
    df_final.to_csv(save_path, index=False)

    print("-" * 30)
    print(f"💾 文件已保存至: {save_path}")
    print("-" * 30)
    print("👀 前 5 行预览:")
    print(df_final.head())

if __name__ == '__main__':
    try:
        fetch_and_save()
    except Exception as e:
        print(f"❌ 程序发生严重错误: {e}")