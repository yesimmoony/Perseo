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
    min_hand_detection_confidence=0.6,
    min_hand_presence_confidence=0.6,
    running_mode=vision.RunningMode.IMAGE,
)
detector = vision.HandLandmarker.create_from_options(options)

UDP_IP = "127.0.0.1"
UDP_PORT = 4242
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

cap = cv2.VideoCapture(0)
DEBUG = True

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
CENTRO_PALMA = 9


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
      "l_action": "NONE",
      "r_action": "NONE",
      "dx": 0.0,
      "dy": 0.0,
      "palm_size": 0.0,
      "cursor_active": False,
      "cursor_x": 0.0,
      "cursor_y": 0.0,
      "is_pinching": False,
  }

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

    # --- MANO IZQUIERDA ---
    if mano_izquierda:
      dedos_levantados = 0
      if mano_izquierda[PUNTA_INDICE].y < mano_izquierda[MEDIO_INDICE].y:
        dedos_levantados += 1
      if mano_izquierda[PUNTA_MAYOR].y < mano_izquierda[MEDIO_MAYOR].y:
        dedos_levantados += 1
      if mano_izquierda[PUNTA_ANULAR].y < mano_izquierda[MEDIO_ANULAR].y:
        dedos_levantados += 1
      if mano_izquierda[PUNTA_MENIQUE].y < mano_izquierda[MEDIO_MENIQUE].y:
        dedos_levantados += 1

      if dedos_levantados <= 1:
        payload["l_action"] = "TOGGLE_PLAY"
      else:
        payload["l_action"] = "ZOOM"
        tamanio_palma = distancia(
            mano_izquierda[MUNIECA], mano_izquierda[CENTRO_PALMA]
        )
        payload["palm_size"] = round(tamanio_palma, 4)

    # --- MANO DERECHA ---
    if mano_derecha:
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
          > 0.12
      )

      postura_activa = (
          tres_dedos_doblados and indice_estirado and pulgar_separado
      )

      if postura_activa:
        distancia_pinch = distancia(
            mano_derecha[PUNTA_PULGAR], mano_derecha[PUNTA_INDICE]
        )
        haciendo_pinch = distancia_pinch < 0.055

        punto_puntero = mano_derecha[PUNTA_INDICE]
        payload["cursor_active"] = True
        payload["cursor_x"] = round(punto_puntero.x, 4)
        payload["cursor_y"] = round(punto_puntero.y, 4)
        payload["is_pinching"] = haciendo_pinch
        payload["r_action"] = "PINCH" if haciendo_pinch else "APUNTANDO"
      else:
        payload["cursor_active"] = False
        payload["cursor_x"] = 0.0
        payload["cursor_y"] = 0.0
        payload["is_pinching"] = False
        payload["r_action"] = "NINGUNO"

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

    color_estado = (140, 140, 140)
    if payload.get("cursor_active"):
      color_estado = (0, 0, 255) if payload.get("is_pinching") else (0, 255, 0)
      pos_mira_x = int(payload["cursor_x"] * ancho)
      pos_mira_y = int(payload["cursor_y"] * alto)
      cv2.circle(image, (pos_mira_x, pos_mira_y), 14, color_estado, 2)
      cv2.circle(image, (pos_mira_x, pos_mira_y), 3, color_estado, -1)

    texto_estado = (
        f"Mano D: {payload['r_action']} | Click: {payload.get('is_pinching')}"
    )
    cv2.putText(
        image,
        texto_estado,
        (10, 60),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        color_estado,
        2,
    )
    cv2.imshow("Hand Tracking Debug", image)

    if cv2.waitKey(1) & 0xFF == ord("q"):
      break

cap.release()
cv2.destroyAllWindows()