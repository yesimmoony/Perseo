import ctypes
import json
import math
import os
import socket
import sys
import urllib.request
import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

# --- CALIBRACION DE SENSIBILIDAD Y SUAVIZADO ---
UMBRAL_ACTIVAR_PINCH = 0.15
UMBRAL_MANTENER_PINCH = 0.15
FACTOR_SUAVIZADO = 0.15
ZONA_MUERTA = 0.003
TOLERANCIA_CUADROS = 4

# --- CONFIGURACION Y PROCESO ---
parent_pid = None
if len(sys.argv) > 1:
  try:
    parent_pid = int(sys.argv[-1])
  except ValueError:
    pass


def is_godot_alive(pid):
  if not pid:
    return True
  try:
    handle = ctypes.windll.kernel32.OpenProcess(0x1000, False, pid)
    if handle:
      exit_code = ctypes.c_ulong()
      ctypes.windll.kernel32.GetExitCodeProcess(handle, ctypes.byref(exit_code))
      ctypes.windll.kernel32.CloseHandle(handle)
      return exit_code.value == 259
    else:
      return True
  except Exception:
    return True
  return True


# --- MEDIAPIPE Y RED ---
if getattr(sys, "frozen", False):
  base_dir = os.path.dirname(sys.executable)
else:
  base_dir = os.path.dirname(os.path.abspath(__file__))

MODEL_PATH = os.path.join(base_dir, "hand_landmarker.task")
MODEL_URL = "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"

if not os.path.exists(MODEL_PATH):
  urllib.request.urlretrieve(MODEL_URL, MODEL_PATH)

base_options = python.BaseOptions(model_asset_path=MODEL_PATH)
options = vision.HandLandmarkerOptions(
    base_options=base_options,
    num_hands=2,
    min_hand_detection_confidence=0.5,
    min_hand_presence_confidence=0.5,
    running_mode=vision.RunningMode.IMAGE,
)
detector = vision.HandLandmarker.create_from_options(options)

UDP_IP = "127.0.0.1"
UDP_PORT = 4242
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

DEBUG = True

pos_previa_izq = None
pinch_sostenido_izq = False
pinch_sostenido_der = False

cursor_suavizado_x = None
cursor_suavizado_y = None

cuadros_perdidos_der = 0
cuadros_perdidos_izq = 0

ultimo_payload_der = {"cursor_active": False, "cursor_x": 0.0, "cursor_y": 0.0, "is_pinching": False}

# --- ESQUELETO ---
HUESOS_MANO = [
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 4),
    (0, 5),
    (5, 6),
    (6, 7),
    (7, 8),
    (5, 9),
    (9, 10),
    (10, 11),
    (11, 12),
    (9, 13),
    (13, 14),
    (14, 15),
    (15, 16),
    (13, 17),
    (17, 18),
    (18, 19),
    (19, 20),
    (0, 17),
]

MUNIECA = 0
PUNTA_PULGAR = 4
MEDIO_INDICE = 6
PUNTA_INDICE = 8
MEDIO_MAYOR = 10
PUNTA_MAYOR = 12
MEDIO_ANULAR = 14
PUNTA_ANULAR = 16
BASE_MENIQUE = 17
MEDIO_MENIQUE = 18
PUNTA_MENIQUE = 20


def distancia(punto_a, punto_b):
  return math.hypot(punto_a.x - punto_b.x, punto_a.y - punto_b.y)


# --- BUCLE PRINCIPAL ---
while cap.isOpened():

  if parent_pid and not is_godot_alive(parent_pid):
    break

  success, image = cap.read()
  if not success:
    continue

  image = cv2.flip(image, 1)
  image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

  mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=image_rgb)
  results = detector.detect(mp_image)

  payload = {
      "l_pinch": False,
      "l_dx": 0.0,
      "l_dy": 0.0,
      "cursor_active": False,
      "cursor_x": 0.0,
      "cursor_y": 0.0,
      "is_pinching": False,
  }

  dist_actual_izq = 0.0
  dist_actual_der = 0.0

  # --- IDENTIFICACION DE MANOS ---
  if results.hand_landmarks and results.handedness:
    mano_izquierda = None
    mano_derecha = None

    for idx, info_mano in enumerate(results.handedness):
      etiqueta = info_mano[0].category_name
      if etiqueta == "Left":
        mano_izquierda = results.hand_landmarks[idx]
      elif etiqueta == "Right":
        mano_derecha = results.hand_landmarks[idx]

    # --- MANO IZQUIERDA (ROTACION / ORBITA) ---
    if mano_izquierda:
      punto_munieca_izq = mano_izquierda[MUNIECA]

      mayor_doblado_izq = distancia(
          mano_izquierda[PUNTA_MAYOR], punto_munieca_izq
      ) < distancia(mano_izquierda[MEDIO_MAYOR], punto_munieca_izq)
      anular_doblado_izq = distancia(
          mano_izquierda[PUNTA_ANULAR], punto_munieca_izq
      ) < distancia(mano_izquierda[MEDIO_ANULAR], punto_munieca_izq)
      menique_doblado_izq = distancia(
          mano_izquierda[PUNTA_MENIQUE], punto_munieca_izq
      ) < distancia(mano_izquierda[MEDIO_MENIQUE], punto_munieca_izq)
      tres_dedos_doblados_izq = (
          mayor_doblado_izq and anular_doblado_izq and menique_doblado_izq
      )

      indice_estirado_izq = distancia(
          mano_izquierda[PUNTA_INDICE], punto_munieca_izq
      ) > distancia(mano_izquierda[MEDIO_INDICE], punto_munieca_izq)
      pulgar_separado_izq = (
          distancia(mano_izquierda[PUNTA_PULGAR], mano_izquierda[BASE_MENIQUE])
          > 0.09
      )

      dist_actual_izq = distancia(
          mano_izquierda[PUNTA_PULGAR], mano_izquierda[PUNTA_INDICE]
      )

      if not pinch_sostenido_izq:
        if dist_actual_izq < UMBRAL_ACTIVAR_PINCH:
          pinch_sostenido_izq = True
          pos_previa_izq = None
      else:
        if dist_actual_izq > UMBRAL_MANTENER_PINCH:
          pinch_sostenido_izq = False
          pos_previa_izq = None

      postura_activa_izq = (
          tres_dedos_doblados_izq
          and indice_estirado_izq
          and (pulgar_separado_izq or pinch_sostenido_izq)
      )

      if postura_activa_izq:
        centro_x = (
            mano_izquierda[PUNTA_PULGAR].x + mano_izquierda[PUNTA_INDICE].x
        ) / 2.0
        centro_y = (
            mano_izquierda[PUNTA_PULGAR].y + mano_izquierda[PUNTA_INDICE].y
        ) / 2.0

        if pinch_sostenido_izq:
          payload["l_pinch"] = True
          if pos_previa_izq:
            prev_x, prev_y = pos_previa_izq
            delta_x = centro_x - prev_x
            delta_y = centro_y - prev_y

            delta_x = max(-0.04, min(0.04, delta_x))
            delta_y = max(-0.04, min(0.04, delta_y))

            if abs(delta_x) > ZONA_MUERTA:
              payload["l_dx"] = round(delta_x, 4)
            if abs(delta_y) > ZONA_MUERTA:
              payload["l_dy"] = round(delta_y, 4)

          pos_previa_izq = (centro_x, centro_y)
        else:
          pos_previa_izq = None
      else:
        pinch_sostenido_izq = False
        pos_previa_izq = None
    else:
      pinch_sostenido_izq = False
      pos_previa_izq = None

    # --- MANO DERECHA (CURSOR Y SELECCION / PAN) ---
    if mano_derecha:
      cuadros_perdidos_der = 0
      punto_munieca = mano_derecha[MUNIECA]

      mayor_doblado = distancia(
          mano_derecha[PUNTA_MAYOR], punto_munieca
      ) < distancia(mano_derecha[MEDIO_MAYOR], punto_munieca)
      anular_doblado = distancia(
          mano_derecha[PUNTA_ANULAR], punto_munieca
      ) < distancia(mano_derecha[MEDIO_ANULAR], punto_munieca)
      menique_doblado = distancia(
          mano_derecha[PUNTA_MENIQUE], punto_munieca
      ) < distancia(mano_derecha[MEDIO_MENIQUE], punto_munieca)
      tres_dedos_doblados = mayor_doblado and anular_doblado and menique_doblado

      indice_estirado = distancia(
          mano_derecha[PUNTA_INDICE], punto_munieca
      ) > distancia(mano_derecha[MEDIO_INDICE], punto_munieca)
      pulgar_separado = (
          distancia(mano_derecha[PUNTA_PULGAR], mano_derecha[BASE_MENIQUE])
          > 0.08
      )

      dist_actual_der = distancia(
          mano_derecha[PUNTA_PULGAR], mano_derecha[PUNTA_INDICE]
      )

      if not pinch_sostenido_der:
        if dist_actual_der < UMBRAL_ACTIVAR_PINCH:
          pinch_sostenido_der = True
      else:
        if dist_actual_der > UMBRAL_MANTENER_PINCH:
          pinch_sostenido_der = False

      postura_activa = (
          tres_dedos_doblados
          and indice_estirado
          and (pulgar_separado or pinch_sostenido_der)
      )

      if postura_activa:
        punto_puntero = mano_derecha[PUNTA_INDICE]

        if cursor_suavizado_x is None:
          cursor_suavizado_x = punto_puntero.x
          cursor_suavizado_y = punto_puntero.y
        else:
          cursor_suavizado_x += (
              punto_puntero.x - cursor_suavizado_x
          ) * FACTOR_SUAVIZADO
          cursor_suavizado_y += (
              punto_puntero.y - cursor_suavizado_y
          ) * FACTOR_SUAVIZADO

        payload["cursor_active"] = True
        payload["cursor_x"] = round(cursor_suavizado_x, 4)
        payload["cursor_y"] = round(cursor_suavizado_y, 4)
        payload["is_pinching"] = pinch_sostenido_der

        ultimo_payload_der = payload.copy()
      else:
        pinch_sostenido_der = False
        payload["cursor_active"] = False
        cursor_suavizado_x = None
        cursor_suavizado_y = None
    else:
      cuadros_perdidos_der += 1
      if (
          cuadros_perdidos_der <= TOLERANCIA_CUADROS
          and ultimo_payload_der["cursor_active"]
      ):
        payload["cursor_active"] = ultimo_payload_der["cursor_active"]
        payload["cursor_x"] = ultimo_payload_der["cursor_x"]
        payload["cursor_y"] = ultimo_payload_der["cursor_y"]
        payload["is_pinching"] = ultimo_payload_der["is_pinching"]
      else:
        pinch_sostenido_der = False
        payload["cursor_active"] = False
        cursor_suavizado_x = None
        cursor_suavizado_y = None

  # --- ENVIO DE DATOS ---
  sock.sendto(json.dumps(payload).encode(), (UDP_IP, UDP_PORT))

  # --- VISUALIZACION Y DEBUG ---
  if DEBUG:
    alto, ancho, _ = image.shape

    if results.hand_landmarks:
      for mano in results.hand_landmarks:
        for inicio_idx, fin_idx in HUESOS_MANO:
          pt_inicio = (
              int(mano[inicio_idx].x * ancho),
              int(mano[inicio_idx].y * alto),
          )
          pt_fin = (int(mano[fin_idx].x * ancho), int(mano[fin_idx].y * alto))
          cv2.line(image, pt_inicio, pt_fin, (220, 220, 220), 2)

        for punto in mano:
          cx = int(punto.x * ancho)
          cy = int(punto.y * alto)
          cv2.circle(image, (cx, cy), 4, (0, 255, 0), -1)

    color_cursor = (140, 140, 140)
    if payload.get("cursor_active"):
      color_cursor = (0, 0, 255) if payload.get("is_pinching") else (0, 255, 0)
      pos_mira_x = int(payload["cursor_x"] * ancho)
      pos_mira_y = int(payload["cursor_y"] * alto)
      cv2.circle(image, (pos_mira_x, pos_mira_y), 14, color_cursor, 2)
      cv2.circle(image, (pos_mira_x, pos_mira_y), 3, color_cursor, -1)

    texto_izq = f"Izq Pinch: {payload['l_pinch']} (dist: {round(dist_actual_izq, 3)})"
    texto_der = f"Der Pinch: {payload['is_pinching']} (dist: {round(dist_actual_der, 3)})"

    cv2.putText(
        image, texto_izq, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 200, 0), 2
    )
    cv2.putText(
        image, texto_der, (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.6, color_cursor, 2
    )
    cv2.imshow("Hand Tracking Debug", image)

    if cv2.waitKey(1) & 0xFF == ord("q"):
      break

cap.release()
cv2.destroyAllWindows()