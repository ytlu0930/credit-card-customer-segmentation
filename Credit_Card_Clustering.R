# =======================================================
# 1：載入必要套件
# =======================================================
library(readr)      # [readr] 負責讀取資料
library(dplyr)      # [dplyr] 負責清洗、整理、計算
library(cluster)    # [cluster] 負責分群演算法
library(factoextra) # [factoextra] 負責畫圖評估

# =======================================================
# 2：讀取資料與填補缺失值
# =======================================================
df <- read_csv("CC GENERAL.csv")

# [dplyr] 源頭處理：填補缺失值 (NA)
# 說明：針對 MINIMUM_PAYMENTS 和 CREDIT_LIMIT 用中位數補值
df_clean <- df %>%
  mutate(
    MINIMUM_PAYMENTS = ifelse(is.na(MINIMUM_PAYMENTS), median(MINIMUM_PAYMENTS, na.rm = TRUE), MINIMUM_PAYMENTS),
    CREDIT_LIMIT = ifelse(is.na(CREDIT_LIMIT), median(CREDIT_LIMIT, na.rm = TRUE), CREDIT_LIMIT)
  )

# =======================================================
# 3：建模前處理 (資料變形)
# =======================================================
# [dplyr] 資料變形：移除 ID -> 取 Log 對數 -> Scale 標準化
data_model <- df_clean %>%
  select(-CUST_ID) %>%
  mutate_all(~log1p(.)) %>% 
  scale()

# =======================================================
# 4：建立階層式分群模型與評估
# =======================================================
# [cluster] 計算距離與建立模型
# 1. 計算歐式距離
dist_mat <- dist(data_model, method = "euclidean")
# 2. 建立階層式分群 (Ward's Method)
hc_model <- hclust(dist_mat, method = "ward.D2")

# [factoextra] 繪製評估圖表
# 畫手肘圖 (Elbow Method) 來確認 k=4 是正確的
fviz_nbclust(data_model, FUN = hcut, method = "wss") +
  geom_vline(xintercept = 4, linetype = 2) +
  labs(title = "Elbow Method (Checking k=4)")

# =======================================================
# 5：產出最終業務報表
# =======================================================
# [cluster] 根據模型進行切割 (k=4)
groups <- cutree(hc_model, k = 4)

# [dplyr] 將分群結果 (1,2,3,4) 貼回乾淨的原始資料
final_data <- df_clean %>%
  select(-CUST_ID) %>%
  mutate(Cluster = as.factor(groups))

# [dplyr] 製作業務報表 (Summarise)
cluster_profile <- final_data %>%
  group_by(Cluster) %>%
  summarise(
    人數 = n(),
    平均餘額 = mean(BALANCE),
    平均消費金額 = mean(PURCHASES),
    平均預借現金 = mean(CASH_ADVANCE),
    平均分期消費 = mean(INSTALLMENTS_PURCHASES),
    平均信用額度 = mean(CREDIT_LIMIT),
    平均付款 = mean(PAYMENTS),
    全額還款率 = mean(PRC_FULL_PAYMENT)
  ) %>%
  mutate(
    # [dplyr] 金額類：取整數 (round 0)
    平均餘額 = round(平均餘額, 1),
    平均消費金額 = round(平均消費金額, 1),
    平均預借現金 = round(平均預借現金, 1),
    平均分期消費 = round(平均分期消費, 1),
    平均信用額度 = round(平均信用額度, 1),
    平均付款 = round(平均付款, 1),
    
    # [dplyr] 百分比類：保留 2 位小數，避免變成 0
    全額還款率 = round(全額還款率, 2) 
  )

# =======================================================
# 6：顯示結果
# =======================================================
print(cluster_profile)
View(cluster_profile)

