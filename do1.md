下面是一个 shell 的和 gemini 文档交互的案例 。 

这里要特别说明 项目中的 api key 是一个数组，在这个场景中就不能每次随机了 ，这里是一个会话窗口就只能用一个 API KEY 了。  不管对话多少次都只能用选好的 KEY 。 这个和其他的是不同的逻辑！！！！

DOC_URL_1="https://arxiv.org/pdf/2312.11805"
DOC_URL_2="https://arxiv.org/pdf/2403.05530"
DISPLAY_NAME_1="Gemini_paper"
DISPLAY_NAME_2="Gemini_1.5_paper"
PROMPT="What is the difference between each of the main benchmarks between these two papers? Output these in a table."

# Function to download and upload a PDF
upload_pdf() {
  local doc_url="$1"
  local display_name="$2"

  # Download the PDF
  wget -O "${display_name}.pdf" "${doc_url}"

  local MIME_TYPE=$(file -b --mime-type "${display_name}.pdf")
  local NUM_BYTES=$(wc -c < "${display_name}.pdf")

  echo "MIME_TYPE: ${MIME_TYPE}"
  echo "NUM_BYTES: ${NUM_BYTES}"

  local tmp_header_file=upload-header.tmp

  # Initial resumable request
  curl "${BASE_URL}/upload/v1beta/files?key=${GOOGLE_API_KEY}" \
    -D "${tmp_header_file}" \
    -H "X-Goog-Upload-Protocol: resumable" \
    -H "X-Goog-Upload-Command: start" \
    -H "X-Goog-Upload-Header-Content-Length: ${NUM_BYTES}" \
    -H "X-Goog-Upload-Header-Content-Type: ${MIME_TYPE}" \
    -H "Content-Type: application/json" \
    -d "{'file': {'display_name': '${display_name}'}}" 2> /dev/null

  local upload_url=$(grep -i "x-goog-upload-url: " "${tmp_header_file}" | cut -d" " -f2 | tr -d "\r")
  rm "${tmp_header_file}"

  # Upload the PDF
  curl "${upload_url}" \
    -H "Content-Length: ${NUM_BYTES}" \
    -H "X-Goog-Upload-Offset: 0" \
    -H "X-Goog-Upload-Command: upload, finalize" \
    --data-binary "@${display_name}.pdf" 2> /dev/null > "file_info_${display_name}.json"

  local file_uri=$(jq ".file.uri" "file_info_${display_name}.json")
  echo "file_uri for ${display_name}: ${file_uri}"

  # Clean up the downloaded PDF
  rm "${display_name}.pdf"

  echo "${file_uri}"
}

# Upload the first PDF
file_uri_1=$(upload_pdf "${DOC_URL_1}" "${DISPLAY_NAME_1}")

# Upload the second PDF
file_uri_2=$(upload_pdf "${DOC_URL_2}" "${DISPLAY_NAME_2}")

# Now generate content using both files
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$GOOGLE_API_KEY" \
    -H 'Content-Type: application/json' \
    -X POST \
    -d '{
      "contents": [{
        "parts":[
          {"file_data": {"mime_type": "application/pdf", "file_uri": '$file_uri_1'}},
          {"file_data": {"mime_type": "application/pdf", "file_uri": '$file_uri_2'}},
          {"text": "'$PROMPT'"}
        ]
      }]
    }' 2> /dev/null > response.json

cat response.json
echo

jq ".candidates[].content.parts[].text" response.json