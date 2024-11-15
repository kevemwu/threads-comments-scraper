from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import json
import os
import sys
import time
from parsel import Selector
from nested_lookup import nested_lookup
import jmespath
from datetime import datetime, timezone

def parse_thread(data, target_username, is_reply=False, original_post=None):
    """解析貼文資料"""
    # 檢查是否為目標用戶的貼文或回覆給目標用戶的貼文
    post_username = jmespath.search('post.user.username', data)
    reply_to_username = jmespath.search('post.text_post_app_info.reply_to_author.username', data)
    
    if not (post_username == target_username or reply_to_username == target_username):
        return None
        
    result = jmespath.search("""
    {
        text: post.caption.text,
        published_on: post.taken_at,
        username: post.user.username,
        code: post.code,
        videos: post.video_versions[].url,
        like_count: post.like_count,
        reply_count: post.text_post_app_info.direct_reply_count
    }
    """, data)
    
    username = result.pop('username', '')
    code = result.pop('code', '')
    
    # 取得所有圖片和影片來源
    images = []
    videos = []
    
    # 檢查是否有多張圖片/影片（輪播）
    carousel_media = jmespath.search('post.carousel_media[]', data)
    if carousel_media:
        for media in carousel_media:
            # 檢查是否有影片
            if media.get('video_versions'):
                # 取得最高品質的影片 URL (通常是 type 101)
                video_versions = sorted(media['video_versions'], key=lambda x: x.get('type', 999))
                if video_versions:
                    videos.append(video_versions[0]['url'])
            # 如果沒有影片才加入圖片
            elif media.get('image_versions2', {}).get('candidates'):
                candidates = media['image_versions2']['candidates']
                if len(candidates) > 1:
                    images.append(candidates[1]['url'])
                else:
                    images.append(candidates[0]['url'])
    else:
        # 檢查單一影片
        video_versions = jmespath.search('post.video_versions[]', data)
        if video_versions:
            # 取得最高品質的影片 URL
            sorted_videos = sorted(video_versions, key=lambda x: x.get('type', 999))
            if sorted_videos:
                videos.append(sorted_videos[0]['url'])
        # 如果沒有影片才檢查單張圖片
        elif jmespath.search('post.image_versions2.candidates', data):
            candidates = data['post']['image_versions2']['candidates']
            if len(candidates) > 1:
                images.append(candidates[1]['url'])
            else:
                images.append(candidates[0]['url'])
    
    # 將圖片和影片列表加入 result（如果為空則設為 None）
    result['images'] = images if images else None
    result['videos'] = list(set(videos)) if videos else None
    
    # 將 Unix timestamp 轉換為 ISO 格式的時間字串
    def convert_timestamp(timestamp):
        if timestamp:
            dt = datetime.fromtimestamp(timestamp, tz=timezone.utc)
            return dt.isoformat()
        return None
    
    if is_reply:
        # 回覆需要包含原始貼文資訊
        cleaned_result = {
            'username': username,
            'datetime': convert_timestamp(result.pop('published_on', None)),
            'content': result.pop('text', ''),
            'images': result.get('images'),
            'videos': list(set(result.get('videos', []) or [])) if result.get('videos') else None,
            'post_content': original_post.get('content') if original_post else None,
            'post_datetime': original_post.get('datetime') if original_post else None,
        }
    else:
        cleaned_result = {
            'username': username,
            'code': code,
            'url': f'https://www.threads.net/@{username}/post/{code}' if username and code else None,
            'images': result.get('images'),
            'videos': list(set(result.get('videos', []) or [])) if result.get('videos') else None,
            'datetime': convert_timestamp(result.pop('published_on', None)),
            'content': result.pop('text', ''),
            'likes': result.pop('like_count', 0),
            'direct_replies_count': result.pop('reply_count', 0),
            'thread_items': []
        }
    
    return cleaned_result

def get_thread_replies(driver, post_url, original_code, target_username, original_post):
    """獲取特定貼文的回覆串"""
    driver.get(post_url)
    time.sleep(1)
    
    try:
        WebDriverWait(driver, 20).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "[data-pressable-container=true]"))
        )
        
        selector = Selector(driver.page_source)
        hidden_datasets = selector.css('script[type="application/json"][data-sjs]::text').getall()
        
        all_replies = []
        raw_data = []  # 新增: 儲存原始資料
        
        for dataset in hidden_datasets:
            if '"ScheduledServerJS"' not in dataset or 'thread_items' not in dataset:
                continue
                
            try:
                data = json.loads(dataset)
                raw_data.append(data)  # 新增: 收集原始資料
                thread_items = nested_lookup('thread_items', data)
                
                if thread_items:
                    for thread in thread_items:
                        current_thread = []
                        for post in thread:
                            if 'post' in post:
                                post_code = post['post'].get('code')
                                if post_code != original_code:
                                    reply = parse_thread(post, target_username, is_reply=True, original_post=original_post)
                                    if reply and (reply.get('content') or reply.get('images')):
                                        current_thread.append(reply)
                        if current_thread:
                            all_replies.append({"replies": current_thread})
                            
            except Exception as e:
                print(f"解析回覆資料時發生錯誤: {str(e)}")
                continue
        
        # 新增: 儲存該貼文回覆串的原始資料
        # output_dir = os.path.join(os.path.dirname(__file__), 'output')
        # if not os.path.exists(output_dir):
        #     os.makedirs(output_dir)
        
        # raw_data_path = os.path.join(output_dir, f'replies_{original_code}_raw.json')
        # with open(raw_data_path, 'w', encoding='utf-8') as f:
        #     json.dump(raw_data, f, ensure_ascii=False, indent=2)
                
        return all_replies
        
    except Exception as e:
        print(f"獲取回覆時發生錯誤: {str(e)}")
        return []

def scrape_threads(username):
    output_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'output')
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    raw_data_path = os.path.join(output_dir, f'{username}_raw_data.json')
    
    options = webdriver.ChromeOptions()
    options.add_argument('--headless=new')
    options.add_argument('--disable-gpu')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--window-size=1920,1080')
    options.add_argument('--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
    
    try:
        driver = webdriver.Chrome(options=options)
        url = f'https://www.threads.net/@{username}'
        driver.get(url)
        
        WebDriverWait(driver, 20).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "[data-pressable-container=true]"))
        )
        
        selector = Selector(driver.page_source)
        hidden_datasets = selector.css('script[type="application/json"][data-sjs]::text').getall()
        
        # 儲存原始資料到獨立檔案
        formatted_data = []
        for dataset in hidden_datasets:
            if '"ScheduledServerJS"' not in dataset or 'thread_items' not in dataset:
                continue
            try:
                data = json.loads(dataset)
                formatted_data.append(data)
            except Exception as e:
                print(f"解析原始資料時發生錯誤: {str(e)}")
                continue
                
        # 現在可以使用 raw_data_path 了
        with open(raw_data_path, 'w', encoding='utf-8') as f:
            json.dump(formatted_data, f, ensure_ascii=False, indent=2)
            
        # 繼續處理資料
        all_posts = []
        for data in formatted_data:
            try:
                thread_items = nested_lookup('thread_items', data)
                
                if thread_items:
                    for thread in thread_items:
                        for post in thread:
                            parsed_post = parse_thread(post, username)
                            if parsed_post and (parsed_post.get('content') or parsed_post.get('images')):
                                if parsed_post['url']:
                                    replies = get_thread_replies(
                                        driver, 
                                        parsed_post['url'], 
                                        parsed_post['code'], 
                                        username,
                                        {  # 傳入原始貼文資訊
                                            'content': parsed_post['content'],
                                            'datetime': parsed_post['datetime']
                                        }
                                    )
                                    parsed_post['thread_items'] = replies
                                all_posts.append(parsed_post)
                                
            except Exception as e:
                print(f"解析資料時發生錯誤: {str(e)}")
                continue
        
        # 按時間排序
        sorted_posts = sorted(all_posts, key=lambda x: x['datetime'], reverse=True)
        
        # 修改回傳格式，只回傳必要的資訊
        simplified_posts = [{
            'datetime': post['datetime'],
            'content': post['content'],
            'images': post.get('images', []),
            'direct_replies_count': post['direct_replies_count'],
            'threads': post.get('thread_items', [])
        } for post in sorted_posts]
        
        # 儲存完整結果到檔案
        full_result = {
            'posts': sorted_posts,
            'total': len(sorted_posts)
        }
        json_path = os.path.join(output_dir, f'{username}_result.json')
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(full_result, f, ensure_ascii=False, indent=2)
            
        # 回傳簡化版本的結果
        return json.dumps({'posts': simplified_posts})
        
    except Exception as e:
        print(f"爬取過程發生錯誤: {str(e)}")
        return json.dumps({'error': str(e)})
    finally:
        driver.quit()

if __name__ == '__main__':
    if len(sys.argv) > 1:
        username = sys.argv[1]
        print(f"開始爬取用戶 {username} 的貼文")
        result = scrape_threads(username)