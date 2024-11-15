import sys
import json
from threads_scraper import scrape_threads

def test_scraper(username):
    """
    測試爬蟲功能並檢查結果
    
    參數:
    username (str): 要爬取的Threads用戶名
    """
    print(f"開始測試爬取用戶 {username} 的資料...")
    
    try:
        # 執行爬蟲
        result = scrape_threads(username)
        
        # 解析JSON結果
        data = json.loads(result)
        
        if 'error' in data:
            print(f"爬取失敗: {data['error']}")
            return
            
        # 檢查結果
        posts = data.get('posts', [])
        print(f"\n成功爬取 {len(posts)} 篇貼文")
        
        # 顯示每篇貼文的基本資訊
        for i, post in enumerate(posts, 1):
            print(f"\n貼文 {i}:")
            print(f"時間: {post['datetime']}")
            print(f"內容: {post['content'][:50]}..." if len(post['content']) > 50 else f"內容: {post['content']}")
            if post.get('images'):
                print(f"圖片數量: {len(post['images'])}")
                
        print("\n完整結果已儲存在 output 目錄中")
        
    except Exception as e:
        print(f"測試過程發生錯誤: {str(e)}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        username = sys.argv[1]
        test_scraper(username)
    else:
        print("請提供要測試的用戶名")
        print("使用方式: python test_scraper.py <username>")