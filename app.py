# -*- coding: utf-8 -*-
import os
import sys
import pandas as pd
import re
import time
import logging
import threading
import collections
from flask_cors import CORS

from flask import Flask, request, jsonify

from chromadb.config import DEFAULT_TENANT, DEFAULT_DATABASE, Settings
from chromadb import PersistentClient
from chromadb.utils import embedding_functions
import google.generativeai as genai
from google.generativeai.types.safety_types import HarmCategory, HarmBlockThreshold

# --- Yapılandırma ve Başlangıç Ayarları ---

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

CHROMA_DB_BASE_PATH = os.getenv('CHROMA_DB_PATH', './chroma_db_data')
EXCEL_FILE_PATH = os.getenv('EXCEL_FILE_PATH', './data/son_guncellenmis_dosya.xlsx')
os.makedirs(CHROMA_DB_BASE_PATH, exist_ok=True)
os.makedirs(os.path.dirname(EXCEL_FILE_PATH), exist_ok=True)

MODEL_CONFIG = {
    "DistilUSE": {
        "model_name": "distiluse-base-multilingual-cased-v1",
        "collection_name": "RuyaTabirleri_distiluse"
    },
    "BERT-Turkish": {
        "model_name": "emrecan/bert-base-turkish-cased-mean-nli-stsb-tr",
        "collection_name": "RuyaTabirleri_bert_turkish"
    },
    "PubMedBERT": {
        "model_name": "NeuML/pubmedbert-base-embeddings",
        "collection_name": "RuyaTabirleri_pubmed"
    },
    "GIST": {
        "model_name": "avsolatorio/GIST-small-Embedding-v0",
        "collection_name": "RuyaTabirleri_gist"
    }
}

safety_settings = {
    HarmCategory.HARM_CATEGORY_HARASSMENT: HarmBlockThreshold.BLOCK_ONLY_HIGH,
    HarmCategory.HARM_CATEGORY_HATE_SPEECH: HarmBlockThreshold.BLOCK_ONLY_HIGH,
    HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: HarmBlockThreshold.BLOCK_ONLY_HIGH,
    HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: HarmBlockThreshold.BLOCK_ONLY_HIGH,
}

# --- Yardımcı Fonksiyonlar (Değişiklik Yok) ---
def create_chroma_client(collection_name, embedding_function, chroma_db_path):
    chroma_client = PersistentClient(
        path=chroma_db_path,
        settings=Settings(),
        tenant=DEFAULT_TENANT,
        database=DEFAULT_DATABASE
    )
    full_collection_name = f"{collection_name}"
    chroma_collection = chroma_client.get_or_create_collection(
        name=full_collection_name,
        embedding_function=embedding_function
    )
    logging.info(f"ChromaDB istemcisi ve koleksiyon '{full_collection_name}' hazırlandı/yüklendi. Path: {chroma_db_path}")
    return chroma_client, chroma_collection

def load_excel_to_chromadb(collection_name, sentence_transformer_model, chroma_db_path, file_path, batch_size=4000):
    logging.info(f"Excel dosyasından '{file_path}' ChromaDB'ye '{collection_name}' yükleniyor (batch_size={batch_size})....")
    try:
        df = pd.read_excel(file_path)
        if 'Rüya' not in df.columns or 'Yorum' not in df.columns:
            raise ValueError("Excel dosyasında 'Rüya' ve 'Yorum' sütunları olmalı.")

        ruyalar = df['Rüya'].tolist()
        yorumlar = df['Yorum'].tolist()
        ids_orig = [str(i) for i in range(len(ruyalar))]
        metadatas_orig = [{'yorum': yorum} for yorum in yorumlar]

        embedding_function = embedding_functions.SentenceTransformerEmbeddingFunction(
            model_name=sentence_transformer_model
        )
        chroma_client, chroma_collection = create_chroma_client(
            collection_name, embedding_function, chroma_db_path
        )

        current_count = chroma_collection.count()
        total_docs = len(ruyalar)

        if current_count < total_docs or True: # Force update or check for updates
            logging.info(f"'{collection_name}' koleksiyonuna {total_docs} öğe {batch_size} boyutlu batch'ler halinde ekleniyor/güncelleniyor...")
            for i in range(0, total_docs, batch_size):
                batch_end = min(i + batch_size, total_docs)
                batch_ids = ids_orig[i:batch_end]
                batch_documents = ruyalar[i:batch_end]
                batch_metadatas = metadatas_orig[i:batch_end]
                if not batch_documents:
                    continue
                logging.info(f"  Batch {i // batch_size + 1}: {len(batch_documents)} öğe ekleniyor (ID'ler {batch_ids[0]}...{batch_ids[-1]})")
                chroma_collection.upsert(
                    ids=batch_ids,
                    documents=batch_documents,
                    metadatas=batch_metadatas
                )
                logging.info(f"  Batch {i // batch_size + 1} tamamlandı.")
            logging.info(f"Koleksiyona toplam {total_docs} rüya-yorum çifti eklendi/güncellendi.")
        else:
            logging.info(f"'{collection_name}' koleksiyonu zaten güncel ({current_count} öğe).")

        final_count = chroma_collection.count()
        logging.info(f"'{collection_name}' koleksiyonunda toplam {final_count} öğe var.")
        if final_count != total_docs and (current_count < total_docs or True):
            logging.warning(f"DİKKAT: Eklenen öğe sayısı ({final_count}) Excel'deki öğe sayısıyla ({total_docs}) eşleşmiyor!")
        return chroma_client, chroma_collection
    except FileNotFoundError:
        logging.error(f"Excel dosyası bulunamadı: {file_path}")
        raise
    except Exception as e:
        logging.error(f"Excel yüklenirken hata oluştu: {e}")
        raise

def load_existing_chromadb(collection_name, sentence_transformer_model, chroma_db_path):
    logging.info(f"Mevcut ChromaDB koleksiyonu '{collection_name}' yükleniyor...")
    embedding_function = embedding_functions.SentenceTransformerEmbeddingFunction(
        model_name=sentence_transformer_model
    )
    chroma_client, chroma_collection = create_chroma_client(
        collection_name, embedding_function, chroma_db_path
    )
    count = chroma_collection.count()
    if count == 0:
        logging.warning(f"UYARI: Koleksiyon '{collection_name}' boş! Excel yüklemesi denenmeli.")
    logging.info(f"Mevcut koleksiyon '{collection_name}' yüklendi: {count} öğe.")
    return chroma_client, chroma_collection

def retrieve_docs(chroma_collection, query, n_results=5):
    try:
        results = chroma_collection.query(
            query_texts=[query],
            n_results=n_results,
            include=['documents', 'metadatas', 'distances']
        )
        return results
    except Exception as e:
        logging.error(f"ChromaDB sorgusu sırasında hata: {e}")
        return {'documents': [[]], 'metadatas': [[]], 'distances': [[]]}

def filter_relevant_result(docs, metadatas, distances):
    if docs and docs[0]:
        return docs[0][0], metadatas[0][0].get('yorum', 'Yorum bulunamadı.'), distances[0][0]
    return "Uygun rüya bulunamadı", "Yorum bulunamadı.", float('inf')

def build_chatbot(system_prompt, api_key):
    try:
        genai.configure(api_key=api_key)
        model_name_to_use = 'learnlm-2.0-flash-experimental' # Orijinal dosyadan gelen
        logging.info(f"Gemini modeli olarak '{model_name_to_use}' kullanılıyor.")
        model = genai.GenerativeModel(model_name_to_use, safety_settings=safety_settings)
        chat = model.start_chat()
        chat.send_message(system_prompt)
        logging.info(f"Gemini Chatbot ({model_name_to_use}) başarıyla oluşturuldu.")
        return chat
    except Exception as e:
        logging.error(f"Gemini Chatbot oluşturulurken hata: {e}")
        return None

REQUEST_DELAY = 1.0

def generate_llm_answer(prompt, context, chat, delay=REQUEST_DELAY):
    if chat is None:
        logging.error("LLM Chatbot başlatılamadığı için yanıt üretilemiyor.")
        return "Chatbot hatası nedeniyle yorum yapılamadı."
    try:
        full_prompt = f"{prompt}\n\n{context}".strip()
        response = chat.send_message(full_prompt)
        time.sleep(delay)
        return response.text
    except Exception as e:
        logging.error(f"LLM yanıtı alınırken hata: {e}")
        if "RateLimitError" in str(e):
             return "API kullanım limiti aşıldı. Lütfen daha sonra tekrar deneyin."
        return f"Model ile iletişimde hata oluştu: {e}"

def generate_queries(rewrite_chat, query, delay=REQUEST_DELAY):
    rewrite_prompt = f"""Rüyada geçen **anahtar unsurları** (nesneler, varlıklar -insan, hayvan, mitolojik figür vb.-, yerler, olaylar, duygular) ve bu unsurlarla ilişkili **eylemleri/durumları** (görmek, yapmak, olmak, hissetmek vb.) belirle. Bu metni analiz ederek, her bir unsur için uygun sorgular üret. Her sorgu, "Rüyada [Nesne/Varlık] [Eylem]" formatında olmalı ve ayrı bir satırda yazılmalıdır. Ayrıca, tanımlayıcı özellikleri içeren KULLANICININ RÜYASINA UYGUN varyantlarını da ekle. Yanıtlarını sadece sorgular listesi olarak, her satıra bir sorgu gelecek şekilde ver. Açıklama yapma, sadece sorguları üret: {query}"""
    rewritten_query_text = generate_llm_answer(rewrite_prompt, "", rewrite_chat, delay)
    queries = []
    for line in rewritten_query_text.split('\n'):
        line = line.strip()
        line = re.sub(r'^[*\-–—]\s*', '', line)
        if line and "rüyada" in line.lower():
             if line.lower().startswith("rüyada"):
                 if len(line.split()) > 2:
                    queries.append(line)
    if not queries:
        logging.warning(f"Yeniden yazma modeli sorgu üretemedi. Orijinal metin sorgu olarak kullanılıyor: '{query}'")
        queries.append(f"Rüyada {query}")
    logging.info(f"Üretilen Rüya Sorguları: {queries}")
    return queries

def generate_model_answer(interpretation_chat, chroma_collection, model_display_name, query, queries, n_results=5, delay=REQUEST_DELAY):
    query_results = []
    logging.info(f"--- {model_display_name} için Yorumlar Aranıyor ---")
    for q in queries:
        results = retrieve_docs(chroma_collection, q, n_results)
        if results and results['documents'] and results['documents'][0]:
             ruya, yorum, dist = filter_relevant_result(results['documents'], results['metadatas'], results['distances'])
             logging.info(f" Sorgu: '{q}' -> Bulunan Rüya: '{ruya[:50]}...', Mesafe: {dist:.4f}")
             query_results.append({"query": q, "ruya": ruya, "yorum": yorum})
        else:
             logging.warning(f" Sorgu: '{q}' -> {model_display_name} için uygun rüya bulunamadı.")
             query_results.append({"query": q, "ruya": None, "yorum": None})
    return query_results

# DEĞİŞİKLİK BURADA: original_user_query parametresi eklendi ve prompt güncellendi.
def select_best_model(selection_chat, query_interpretations, model_names, original_user_query, delay=REQUEST_DELAY):
    if not query_interpretations:
        logging.warning("Seçilecek yorum bulunamadı.")
        return {}

    prompt = f"""KULLANICININ RÜYASI: '{original_user_query}'

    Aşağıdaki her bir 'Sorgu' için, sunulan modellerin bulduğu 'Rüya' kısmını değerlendir.
    Görevin, her 'Sorgu' için en uygun ve KULLANICININ RÜYASI ile semantik olarak en alakalı olan 'Rüya' metnine sahip modeli seçmektir.
    Eğer bir modelin bulduğu 'Rüya' metni, 'KULLANICININ RÜYASI' ile veya ilgili 'Sorgu' ile tamamen alakasız görünüyorsa, o modeli değerlendirmeye alma.
    Eğer bir 'Sorgu' için hiçbir model uygun veya alakalı bir 'Rüya' bulamıyorsa, o sorguyu 'Yok' olarak işaretle.

    Sunulan Sorgular ve Model Yorumları:
    """
    for i, qi in enumerate(query_interpretations):
        prompt += f"Sorgu {i+1}: {qi['query']}\n"
        found_any_result = False # Track if any model found *any* result, regardless of relevance
        for j, model_name in enumerate(model_names):
            model_data = qi["models"].get(model_name)
            ruya = model_data.get('ruya', "Yorum bulunamadı") if model_data else "Yorum bulunamadı"
            yorum = model_data.get('yorum', "") if model_data else ""
            # Only include if rüya was actually found (not "Yorum bulunamadı" default)
            if model_data and model_data.get('ruya') and model_data.get('yorum'):
                prompt += f"Model {j+1} ({model_name}): Rüya='{ruya[:100]}...' Yorum='{yorum[:100]}...'\n"
                found_any_result = True
        if not found_any_result:
            prompt += "Bu sorgu için hiçbir model yorum bulamadı.\n" # Indicate to LLM if no raw result was found
        prompt += "\n"

    prompt += """Yanıtını sadece aşağıdaki formatta ver (her satırda bir sorgu için seçim):
    Sorgu 1: [model numarası]
    Sorgu 2: [model numarası]
    ...
    Eğer bir sorgu için uygun yorum bulunamadıysa veya alakalı 'Rüya' metni yoksa, o sorgu için 'Sorgu X: Yok' yaz.
    """

    if selection_chat:
        response_text = generate_llm_answer(prompt, "", selection_chat, delay)
    else:
        logging.warning("Seçim Chatbot'u mevcut değil, varsayılan (ilk geçerli) model kullanılacak.")
        selections = {}
        for i in range(1, len(query_interpretations) + 1):
            found_valid_for_fallback = False
            for model_idx, model_name_iter in enumerate(model_names):
                model_data = query_interpretations[i-1]["models"].get(model_name_iter)
                if model_data and model_data.get('ruya') and model_data.get('yorum'):
                    selections[i] = model_idx # Pick first valid one
                    found_valid_for_fallback = True
                    break
            if not found_valid_for_fallback:
                selections[i] = -1 # No valid entry found even for fallback
        logging.info(f"Varsayılan model seçimleri (fallback): {selections}")
        return selections

    selections = {}
    try:
        lines = response_text.strip().split('\n')
        for line in lines:
            line = line.strip()
            if line.startswith("Sorgu "):
                parts = line.split(':')
                if len(parts) == 2:
                    try:
                        query_num_str = parts[0].split()[1]
                        qn = int(query_num_str)
                        selection_str = parts[1].strip().lower()
                        if selection_str == 'yok' or not selection_str.isdigit():
                            model_index = -1 # LLM explicitly said 'Yok'
                        else:
                            model_num = int(selection_str)
                            if 1 <= model_num <= len(model_names):
                                model_index = model_num - 1
                            else:
                                logging.warning(f"Geçersiz model numarası {model_num} alındı, Sorgu {qn} için varsayılan (ilk geçerli) model kullanılacak.")
                                # Fallback for invalid number: try to find first valid one
                                found_valid_for_parse_error = False
                                for model_idx, model_name_iter in enumerate(model_names):
                                    model_data = query_interpretations[qn-1]["models"].get(model_name_iter)
                                    if model_data and model_data.get('ruya') and model_data.get('yorum'):
                                        model_index = model_idx
                                        found_valid_for_parse_error = True
                                        break
                                if not found_valid_for_parse_error:
                                    model_index = -1
                        selections[qn] = model_index
                    except (ValueError, IndexError) as e:
                        logging.warning(f"Seçim yanıtı ayrıştırılamadı: '{line}'. Hata: {e}. Sorgu için varsayılan (ilk geçerli) kullanılacak.")
                        try:
                            qn_val = int(parts[0].split()[1])
                            # Fallback: Find the first model that actually has data
                            found_valid_for_parse_error = False
                            for model_idx, model_name_iter in enumerate(model_names):
                                model_data = query_interpretations[qn_val-1]["models"].get(model_name_iter)
                                if model_data and model_data.get('ruya') and model_data.get('yorum'):
                                    selections[qn_val] = model_idx
                                    found_valid_for_parse_error = True
                                    break
                            if not found_valid_for_parse_error:
                                selections[qn_val] = -1 # No valid model found even for fallback
                        except Exception as inner_e:
                            logging.error(f"Dahili fallback hatası (parse error): {inner_e}. Sorgu atlandı.")
                            pass
    except Exception as e:
        logging.error(f"Model seçimi sırasında genel hata: {e}. Tüm sorgular için varsayılan (ilk geçerli) kullanılacak.")
        # Fallback for general parsing error
        for i in range(1, len(query_interpretations) + 1):
            found_valid_for_general_error = False
            for model_idx, model_name_iter in enumerate(model_names):
                model_data = query_interpretations[i-1]["models"].get(model_name_iter)
                if model_data and model_data.get('ruya') and model_data.get('yorum'):
                    selections[i] = model_idx
                    found_valid_for_general_error = True
                    break
            if not found_valid_for_general_error:
                selections[i] = -1

    # Final check and fallback for any queries LLM didn't explicitly select or had issues with
    for i in range(1, len(query_interpretations) + 1):
        if i not in selections: # If LLM didn't provide any selection for this query
            found_valid = False
            for model_idx, model_name_iter in enumerate(model_names):
                model_data = query_interpretations[i-1]["models"].get(model_name_iter)
                if model_data and model_data.get('ruya') and model_data.get('yorum'):
                    selections[i] = model_idx
                    logging.info(f"Sorgu {i} için LLM seçim yapmadı, ilk geçerli model ({model_names[model_idx]}) seçildi.")
                    found_valid = True
                    break
            if not found_valid:
                selections[i] = -1
                logging.warning(f"Sorgu {i} için hiçbir model geçerli yorum bulamadı.")
        # If LLM explicitly said 'Yok', we respect that. No further fallback is needed.
        elif selections[i] == -1:
            logging.info(f"Sorgu {i} için LLM, uygun model bulunmadığını belirtti.")

    logging.info(f"Model Seçimleri (indeks bazlı, -1=yok): {selections}")
    return selections


def generate_user_friendly_output(query, best_responses, interpretation_chat, delay=REQUEST_DELAY):
    if not best_responses:
        logging.info("generate_user_friendly_output: best_responses boş, uygun yorum bulunamadı mesajı üretiliyor.")
        return "Rüyanızla ilgili maalesef uygun bir tabir bulunamadı."

    output_parts = []
    yorum_gruplari = {}
    for original_query_text, (model_name, ruya, yorum) in best_responses.items():
        ruya_unsuru = original_query_text.replace('Rüyada', '').strip()
        if yorum in yorum_gruplari:
            yorum_gruplari[yorum].append(f"'{ruya_unsuru}'")
        else:
            yorum_gruplari[yorum] = [f"'{ruya_unsuru}'"]

    for yorum_metni, ruya_unsurlari_listesi in yorum_gruplari.items():
        unsurlar_baslik = ", ".join(ruya_unsurlari_listesi)
        output_parts.append(f"**{unsurlar_baslik}**: {yorum_metni}")

    formatted_interpretations = "\n\n".join(output_parts)
    final_output_message = "Rüyanızda gördüklerinizi şöyle yorumlayabiliriz:\n\n" + formatted_interpretations

    if not yorum_gruplari:
        logging.warning("generate_user_friendly_output: Yorum grupları boş, genel yorum üretilemiyor.")
        final_output_message += "\n\n**Rüyanızın Genel Yorumu**:\nUygun tabirler bulunamadığı için genel bir yorum yapılamamaktadır."
        return final_output_message.strip()

    unique_yorum_texts = list(yorum_gruplari.keys())
    context_for_general_comment = "\n".join([f"- {yorum_text}" for yorum_text in unique_yorum_texts])
    general_prompt = f"""Kullanıcının rüyası: '{query}'.
Aşağıdaki rüya tabirlerini kullanarak rüyanın genel bir yorumunu akıcı bir dille yaz. Sadece verilen tabirlere sadık kal, dışarıdan bilgi ekleme veya kişisel yorum katma.

Bulunan Tabirler:
{context_for_general_comment}

Rüyanın Genel Yorumu:"""
    logging.info(f"Genel yorum için LLM'e gönderilecek prompt: {general_prompt[:500]}...")
    general_comment = generate_llm_answer(general_prompt, "", interpretation_chat, delay)
    final_output_message += f"\n\n**Rüyanızın Genel Yorumu**:\n{general_comment}"
    return final_output_message.strip()

# --- get_interpretation FONKSİYONU DEĞİŞMİYOR, SADECE ARKA PLAN THREAD'İ TARAFINDAN ÇAĞRILACAK ---
# Bu fonksiyon artık doğrudan HTTP isteğiyle tetiklenmeyecek, kuyruktan alınıp işlenecek.
def get_interpretation_for_queue(query, interpretation_chat, rewrite_chat, chroma_collections_map, model_names_list, delay=REQUEST_DELAY):
    logging.info(f"Kuyruktan rüya yorumlama isteği işleniyor: '{query}'")
    queries = generate_queries(rewrite_chat, query, delay)
    if not queries:
        logging.warning("Hiçbir sorgu üretilemedi. Orijinal rüya sorgu olarak kullanılıyor.")
        queries = [f"Rüyada {query}"]
    logging.info(f"--- Üretilen Sorgular ({len(queries)} adet) ---")
    for i, q_text in enumerate(queries):
        logging.info(f"  Sorgu {i+1}: {q_text}")
    logging.info("------------------------------")

    all_interpretations = {}
    for model_name in model_names_list:
        coll = chroma_collections_map.get(model_name)
        if coll:
            all_interpretations[model_name] = generate_model_answer(interpretation_chat, coll, model_name, query, queries, delay=delay)
        else:
            logging.warning(f"{model_name} için ChromaDB koleksiyonu bulunamadı.")
            all_interpretations[model_name] = [{"query": q_text, "ruya": None, "yorum": None} for q_text in queries]

    query_interpretations_structured = []
    for i, q_text in enumerate(queries):
        d = {"query": q_text, "models": {}}
        for model_name in model_names_list:
            try:
                model_result_for_query = all_interpretations[model_name][i]
                if model_result_for_query['query'] == q_text:
                    d["models"][model_name] = {
                        "ruya": model_result_for_query.get('ruya'),
                        "yorum": model_result_for_query.get('yorum')
                    }
                else:
                    logging.warning(f"Sorgu eşleşme sorunu: Beklenen '{q_text}', bulunan '{model_result_for_query['query']}' ({model_name}, index {i})")
                    d["models"][model_name] = {"ruya": None, "yorum": None}
            except IndexError:
                logging.warning(f"{model_name} için '{q_text}' sorgusuna ait sonuç bulunamadı (IndexError).")
                d["models"][model_name] = {"ruya": None, "yorum": None}
            except Exception as e:
                logging.error(f"Yapılandırma sırasında hata ({model_name}, sorgu '{q_text}'): {e}")
                d["models"][model_name] = {"ruya": None, "yorum": None}
        query_interpretations_structured.append(d)

    # DEĞİŞİKLİK BURADA: original_user_query parametresi select_best_model'a iletiliyor
    selections_by_llm = select_best_model(interpretation_chat, query_interpretations_structured, model_names_list, query, delay)

    logging.info(f"--- LLM Tarafından Yapılan Model Seçimleri (Sorgu Bazlı) ---")
    if not selections_by_llm: logging.info("  LLM tarafından herhangi bir seçim yapılmadı veya alınamadı.")
    else:
        for query_idx_plus_1, model_idx in selections_by_llm.items():
            query_index = query_idx_plus_1 - 1
            if 0 <= query_index < len(query_interpretations_structured):
                original_query_text = query_interpretations_structured[query_index]['query']
                if model_idx != -1 and model_idx < len(model_names_list):
                    selected_model_name = model_names_list[model_idx]
                    retrieved_data = query_interpretations_structured[query_index]['models'].get(selected_model_name)
                    retrieved_ruya = retrieved_data.get('ruya', "N/A") if retrieved_data else "N/A"
                    logging.info(f"  Sorgu {query_idx_plus_1} ('{original_query_text}'):")
                    logging.info(f"    -> Seçilen Model: {selected_model_name} (İndeks: {model_idx})")
                    logging.info(f"    -> Bu modelin bulduğu rüya: '{retrieved_ruya[:100]}...'")
                elif model_idx == -1:
                    logging.info(f"  Sorgu {query_idx_plus_1} ('{original_query_text}'):")
                    logging.info(f"    -> LLM bu sorgu için uygun model BULAMADIĞINI belirtti.")
                else:
                    logging.warning(f"  Sorgu {query_idx_plus_1} ('{original_query_text}'):")
                    logging.warning(f"    -> LLM tarafından geçersiz model indeksi ({model_idx}) döndü.")
            else: logging.warning(f"  Seçimlerde geçersiz sorgu indeksi ({query_idx_plus_1}) bulundu.")
    logging.info("---------------------------------------------------------")

    best_responses = {}
    for query_index_plus_1, model_index in selections_by_llm.items():
        query_index = query_index_plus_1 - 1
        if query_index < 0 or query_index >= len(query_interpretations_structured):
            logging.warning(f"Geçersiz sorgu indeksi {query_index} (selections_by_llm'den) atlandı.")
            continue
        original_query_text = query_interpretations_structured[query_index]['query']
        if model_index != -1: # Sadece LLM'in 'Yok' demediği durumları dahil et
            if model_index < len(model_names_list):
                selected_model_name = model_names_list[model_index]
                model_result = query_interpretations_structured[query_index]['models'].get(selected_model_name)
                if model_result and model_result.get('ruya') and model_result.get('yorum'):
                    ruya = model_result['ruya']
                    yorum = model_result['yorum']
                    best_responses[original_query_text] = (selected_model_name, ruya, yorum)
                else:
                    logging.warning(f"LLM'in seçtiği model ({selected_model_name}), '{original_query_text}' sorgusu için geçerli rüya/yorum içermiyor. Bu sorgu için alternatif aranıyor...")
                    # LLM'in seçtiği model boş döndüyse burada bir fallback mantığı düşünebiliriz
                    # Örneğin, LLM'e yeniden sordurabilir veya diğer modellerden ilk geçerliyi alabiliriz.
                    # Şu anki haliyle, geçerli yorum bulamayanları best_responses'a eklemez.
            else:
                logging.warning(f"LLM tarafından '{original_query_text}' sorgusu için geçersiz model indeksi ({model_index}) döndü. Bu sorgu atlanıyor.")
        else:
            logging.info(f"LLM, '{original_query_text}' sorgusu için uygun bir model bulunmadığını belirtti. Bu sorgu için yorum üretilmeyecek.")


    logging.info(f"--- Yorum Üretiminde Kullanılacak Nihai Seçimler ({len(best_responses)} adet) ---")
    if not best_responses: logging.info("  Nihai yorum üretimi için uygun yanıt bulunamadı.")
    else:
        query_counter = 1
        for original_query, (model_name, ruya, yorum) in best_responses.items():
            logging.info(f"  Yanıt {query_counter}: Orijinal Sorgu: '{original_query}', Seçilen Model: {model_name}, Bulunan Rüya: '{ruya[:100]}...'")
            query_counter += 1
    logging.info("-----------------------------------------------------------------")

    final_output = generate_user_friendly_output(query, best_responses, interpretation_chat, delay)
    logging.info(f"Yorumlama tamamlandı. Sonuç uzunluğu: {len(final_output)}")
    return final_output


# --- Global Değişkenler ve Başlatma ---
app = Flask(__name__)
CORS(app) # CORS'u tüm route'lar için etkinleştir

API_KEYS = [key for key in [
    os.environ.get('GOOGLE_API_KEY_1'),
    os.environ.get('GOOGLE_API_KEY_2'),
    os.environ.get('GOOGLE_API_KEY_3'),
    os.environ.get('GOOGLE_API_KEY_4')
] if key]
if not API_KEYS:
    raise ValueError("Hiçbir Google API Anahtarı bulunamadı. Lütfen GOOGLE_API_KEY_x çevre değişkenlerini ayarlayın.")
logging.info(f"{len(API_KEYS)} adet Google API anahtarı yüklendi.")

chroma_collections = {}
user_chats = [] # Bu artık chatbotları tutacak
model_names_global = list(MODEL_CONFIG.keys()) # Embedding modellerinin isimleri
user_id_counter = 0 # Chatbot rotasyonu için
user_id_lock = threading.Lock()

# Rüya işleme kuyruğu ve işlenmiş sonuçlar için
dream_queue = collections.deque()
processed_interpretations = {} # { "orijinal_ruya_metni": "yorum_sonucu" }
queue_lock = threading.Lock()
processed_lock = threading.Lock()
stop_event = threading.Event() # Arka plan thread'ini durdurmak için

def initialize_resources():
    global chroma_collections, user_chats
    logging.info("Kaynaklar başlatılıyor...")
    if not os.path.exists(EXCEL_FILE_PATH):
         logging.error(f"Excel dosyası bulunamadı: {EXCEL_FILE_PATH}. Yükleme yapılamaz.")

    for model_key, config in MODEL_CONFIG.items():
        chroma_db_path_for_model = os.path.join(CHROMA_DB_BASE_PATH, config['collection_name'])
        os.makedirs(chroma_db_path_for_model, exist_ok=True)
        try:
            _, collection = load_existing_chromadb(
                config['collection_name'], config['model_name'], chroma_db_path_for_model
            )
            if collection.count() == 0 and os.path.exists(EXCEL_FILE_PATH):
                 logging.info(f"'{config['collection_name']}' koleksiyonu boş, Excel'den yükleniyor...")
                 _, collection = load_excel_to_chromadb(
                    config['collection_name'], config['model_name'], chroma_db_path_for_model, EXCEL_FILE_PATH
                 )
            chroma_collections[model_key] = collection
        except Exception as e:
            logging.error(f"{model_key} için ChromaDB yüklenirken/oluşturulurken hata: {e}")
            chroma_collections[model_key] = None

    system_prompt = """Sen bir İslami rüya tabiri uzmanısın. Sana verilen rüya ve ilgili bulunan tabirlere dayanarak rüyanın genel bir yorumunu yapacaksın. Yalnızca sağlanan tabir bilgilerini kullan, dışarıdan bilgi ekleme. Eğer bir unsur için yorum yoksa veya tabirler çelişkili ise bunu belirt. Yanıtlarını Türkçe, doğal, akıcı ve saygılı bir üslupla ver."""
    rewrite_system_prompt = """Sen bir yardımcı asistansın. Görevin, kullanıcının verdiği rüya metnini analiz ederek, rüyada görülen ana unsurları belirlemek ve bu unsurlar için sorgular üretmektir. Her bir unsur için, 'Rüyada [Nesne/Varlık] [Eylem]' formatında birden fazla doğal sorgu oluşturmalısın. Ayrıca, bu sorguların tanımlayıcı özellikler içeren KULLANICININ RÜYASINA UYGUN varyantlarını da üretmelisin. Yanıtlarını sadece sorgular listesi olarak, her satıra bir sorgu gelecek şekilde ver. Açıklama yapma, sadece sorguları üret."""

    for i in range(len(API_KEYS)):
        api_key = API_KEYS[i]
        logging.info(f"Chatbot {i+1} oluşturuluyor (API Key {i+1} ile)...")
        interpretation_chatbot = build_chatbot(system_prompt, api_key)
        rewrite_chatbot = build_chatbot(rewrite_system_prompt, api_key)
        if interpretation_chatbot and rewrite_chatbot:
             user_chats.append({
                 "interpretation_chat": interpretation_chatbot,
                 "rewrite_chat": rewrite_chatbot,
                 "api_key_index": i
             })
             logging.info(f"Chatbot çifti {i+1} başarıyla oluşturuldu.")
        else:
             logging.error(f"Chatbot çifti {i+1} oluşturulamadı (API Key {i+1}). Bu anahtar atlanacak.")
    if not user_chats:
         raise RuntimeError("Hiçbir kullanılabilir chatbot oluşturulamadı. API anahtarlarını veya bağlantıyı kontrol edin.")
    logging.info("Tüm kaynaklar başarıyla başlatıldı.")

# Rüya işleme kuyruğu için arka plan thread fonksiyonu
def process_dream_queue():
    global user_id_counter
    logging.info("Rüya işleme arka plan thread'i başlatıldı.")
    while not stop_event.is_set():
        try:
            dream_to_process = None
            with queue_lock:
                if dream_queue:
                    dream_to_process = dream_queue.popleft()

            if dream_to_process:
                logging.info(f"Kuyruktan '{dream_to_process}' rüyası işlenmek üzere alındı.")

                with user_id_lock:
                    current_user_index = user_id_counter % len(user_chats)
                    selected_chat_pair = user_chats[current_user_index]
                    user_id_counter += 1

                logging.info(f"'{dream_to_process}' rüyası için Chatbot Seti {current_user_index + 1} kullanılıyor.")

                try:
                    interpretation_result = get_interpretation_for_queue(
                        dream_to_process,
                        selected_chat_pair["interpretation_chat"],
                        selected_chat_pair["rewrite_chat"],
                        chroma_collections,
                        model_names_global,
                        delay=REQUEST_DELAY
                    )
                    with processed_lock:
                        processed_interpretations[dream_to_process] = interpretation_result
                    logging.info(f"'{dream_to_process}' rüyası başarıyla yorumlandı ve sonuçlara eklendi.")
                except Exception as e:
                    logging.error(f"'{dream_to_process}' rüyası işlenirken hata oluştu: {e}")
                    with processed_lock:
                        processed_interpretations[dream_to_process] = "Rüyanız işlenirken bir hata oluştu. Lütfen daha sonra tekrar deneyin."

            else:
                time.sleep(5)
        except Exception as e:
            logging.error(f"Rüya işleme thread'inde beklenmedik hata: {e}")
            time.sleep(10)
    logging.info("Rüya işleme arka plan thread'i durduruldu.")


# --- API Endpoint'leri ---
@app.route('/submit_dream', methods=['POST'])
def submit_dream():
    if not request.is_json:
        return jsonify({"error": "İstek JSON formatında olmalı"}), 400
    data = request.get_json()
    dream_text = data.get('ruya')

    if not dream_text or not isinstance(dream_text, str) or len(dream_text.strip()) == 0:
        return jsonify({"error": "'ruya' anahtarı eksik, boş veya geçersiz bir metin"}), 400

    with queue_lock:
        if dream_text in dream_queue or dream_text in processed_interpretations:
            logging.info(f"Rüya '{dream_text[:50]}...' zaten kuyrukta veya işlenmiş. Tekrar eklenmiyor.")
            return jsonify({"message": "Rüyanız başarıyla alındı ve işlenmek üzere sıraya eklendi."}), 200

        dream_queue.append(dream_text)
    logging.info(f"Rüya '{dream_text[:50]}...' kuyruğa eklendi. Kuyruk boyutu: {len(dream_queue)}")
    return jsonify({"message": "Rüyanız başarıyla alındı ve işlenmek üzere sıraya eklendi."}), 200

@app.route('/check_interpretations', methods=['GET'])
def check_interpretations():
    results_to_send = []
    with processed_lock:
        if not processed_interpretations:
            return jsonify([]), 200

        for dream, interpretation in list(processed_interpretations.items()):
            results_to_send.append({"ruya": dream, "yorum": interpretation})
            del processed_interpretations[dream]

    logging.info(f"{len(results_to_send)} adet işlenmiş yorum istemciye gönderiliyor.")
    return jsonify(results_to_send), 200

@app.route('/health', methods=['GET'])
def health_check():
    try:
        status = {
            "status": "healthy",
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "queue_size": len(dream_queue),
            "processed_count": len(processed_interpretations),
            "active_models": len([m for m in chroma_collections.values() if m is not None]),
            "active_chatbots": len(user_chats)
        }
        return jsonify(status), 200
    except Exception as e:
        logging.error(f"Health check sırasında hata: {e}")
        return jsonify({
            "status": "unhealthy",
            "error": str(e),
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
        }), 500

# Flask uygulamasını çalıştırmadan önce kaynakları başlat ve arka plan thread'ini başlat
initialize_resources()

processing_thread = threading.Thread(target=process_dream_queue, daemon=True)
processing_thread.start()

if __name__ == '__main__':
    try:
        app.run(host='0.0.0.0', port=5000, debug=False)
    except KeyboardInterrupt:
        logging.info("Uygulama durduruluyor...")
    finally:
        logging.info("Arka plan thread'inin durması bekleniyor...")
        stop_event.set()
        processing_thread.join(timeout=10)
        if processing_thread.is_alive():
            logging.warning("Arka plan thread'i zamanında durmadı.")
        logging.info("Uygulama tamamen kapatıldı.")