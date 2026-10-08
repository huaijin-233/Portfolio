from action import pos2,setServo
from systemInfo import print_system_info,getUid
from Application import Application
from WiFiManager1 import WiFiManager
 

if __name__ == "__main__":
    
     print_system_info()
     setServo()
     #上面是配网前的动作---------
     wifi_manager = WiFiManager()

     # MQTT配置
     mqtt_config = {
        'server': 'qc10e6c9.ala.cn-hangzhou.emqxsl.cn',  # 替换为你的MQTT服务器地址
        'port': 8883,
        'client_id': getUid(),
        'user': 'user1',  # 如果需要认证
        'password': '123456'  # 如果需要认证
     }
     
     app = Application(wifi_manager, mqtt_config)
     print("已加载 Application")
     app.run()
     pass

       
      