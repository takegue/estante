ENDPOINT=https://www.kurashi.tepco.co.jp
TEPCO_ACCOUNTID=oNN08084473220
TEPCO_PASSWORD=faVt8@37xHWdix9

curl -c cookie.jar -b cookie.jar \
  "$ENDPOINT/kpf-login"  \
  -H 'authority: www.kurashi.tepco.co.jp'  \
  -H 'content-type: application/x-www-form-urlencoded'  \
  -H 'referer: https://www.kurashi.tepco.co.jp/'  \
  --data-raw "ACCOUNTUID=${TEPCO_ACCOUNTID}&PASSWORD=${TEPCO_PASSWORD}&HIDEURL=%2Fpf%2Fja%2Fpc%2Fmypage%2Fhome%2Findex.page%3F&LOGIN=EUAS_LOGIN" \
  --compressed

# curl -qvsc cookie.jar -b cookie.jar \
#   "$ENDPOINT/pf/ja/pc/mypage/learn/comparison.page?ReqID=CsvDL&year=2022&month=2&day=20" --compressed \
#   | iconv -t utf8 -f cp932


# curl -qsb cookie.jar -Li -o /dev/null \
  # "$ENDPOINT/kpf-logout" \
  # -H 'accept-language: ja-JP,ja;q=0.9,en-US;q=0.8,en;q=0.7' \
  # --data-raw 'LOGOUT=EUAS_LOGOUT' \
  # --compressed
