import urllib.request, re
url = 'https://html.duckduckgo.com/html/?q=LNK1140+limit+exceeded+for+program+database'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
try:
    with urllib.request.urlopen(req) as response:
        html = response.read().decode('utf-8')
        snippets = re.findall(r'class=\"result__snippet[^>]*>(.*?)</a>', html, re.IGNORECASE | re.DOTALL)
        for s in snippets[:3]:
            print(re.sub(r'<[^>]+>', '', s).strip())
except Exception as e:
    print('Error:', e)
