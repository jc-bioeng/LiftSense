import math

def smoothing_factor(t_e, cutoff):
    """
    Calcula el coeficiente Alpha (α) para el suavizado exponencial.
    
    Args:
        t_e: Tiempo transcurrido desde la última muestra (Delta Time).
        cutoff: Frecuencia de corte deseada en Hertz (Hz).
        
    Matemáticamente, α se deriva de la constante de tiempo RC: 
    τ = 1 / (2π * cutoff).  α = 1 / (1 + τ/Δt).
    """
    r = 2 * math.pi * cutoff * t_e
    return r / (r + 1)

def exponential_smoothing(a, x, x_prev):
    """
    Aplica la fórmula estándar de Suavizado Exponencial (EMA).
    
    Args:
        a: Factor Alpha (0.0 a 1.0). Determina la inercia del filtro.
        x: Valor actual (la "novedad").
        x_prev: Valor filtrado anterior (el "pasado").
        
    Fórmula: y[t] = α * x[t] + (1 - α) * y[t-1]
    """
    return a * x + (1 - a) * x_prev

class OneEuroFilter:
    def __init__(self, t0, x0, dx0=0.0, min_cutoff=1.0, beta=0.0, d_cutoff=1.0):
        self.min_cutoff = float(min_cutoff)
        self.beta = float(beta)
        self.d_cutoff = float(d_cutoff)
        self.x_prev = float(x0)
        self.dx_prev = float(dx0)
        self.t_prev = float(t0)

    def __call__(self, t, x):
        t_e = t - self.t_prev
        t_e = max(t_e, 1e-5)  # Evitar division by zero

        a_d = smoothing_factor(t_e, self.d_cutoff)
        dx = (x - self.x_prev) / t_e
        dx_hat = exponential_smoothing(a_d, dx, self.dx_prev)

        cutoff = self.min_cutoff + self.beta * abs(dx_hat)
        a = smoothing_factor(t_e, cutoff)
        x_hat = exponential_smoothing(a, x, self.x_prev)

        self.x_prev = x_hat
        self.dx_prev = dx_hat
        self.t_prev = t

        return x_hat

class PoseFilterSession:
    """
    Mantiene el estado de múltiples filtros One-Euro para todos los keypoints de una persona.
    Aplica parámetros más estrictos a los pies para evitar que 'revoloteen'.
    """
    FEET_LANDMARKS = ['l_heel', 'r_heel', 'l_foot_index', 'r_foot_index', 'l_ankle', 'r_ankle']

    def __init__(self, min_cutoff=1.0, beta=0.005, d_cutoff=1.0):
        self.filters = {} 
        self.min_cutoff = min_cutoff
        self.beta = beta
        self.d_cutoff = d_cutoff
        self.last_raw = {}  # Para deadzone

    def process(self, timestamp_ms, keypoints):
        t = timestamp_ms / 1000.0
        filtered_keypoints = {}
        
        for name, kp in keypoints.items():
            conf = kp['conf']
            is_foot = name in self.FEET_LANDMARKS
            
            # Ajuste dinámico: los pies necesitan estabilidad absoluta (min_cutoff casi cero)
            current_min_cutoff = 0.01 if is_foot else self.min_cutoff
            current_beta = 0.001 if is_foot else self.beta

            filtered_kp = {'conf': conf}
            for axis in ['x', 'y']:
                filter_key = f"{name}_{axis}"
                val = kp[axis]
                
                if filter_key not in self.filters:
                    self.filters[filter_key] = OneEuroFilter(
                        t, val, min_cutoff=current_min_cutoff, 
                        beta=current_beta, d_cutoff=self.d_cutoff
                    )
                    filtered_kp[axis] = val
                else:
                    # Deadzone para pies: si el cambio es menor a 1.5px, no mover el filtro
                    if is_foot and name in self.last_raw:
                        prev_val = self.last_raw[name][axis]
                        if abs(val - prev_val) < 1.5:
                            # Mantener valor anterior alimentando el filtro con el mismo dato
                            val = prev_val

                    filtered_kp[axis] = self.filters[filter_key](t, val)
            
            if name not in self.last_raw: self.last_raw[name] = {}
            self.last_raw[name]['x'] = filtered_kp['x']
            self.last_raw[name]['y'] = filtered_kp['y']
            
            filtered_keypoints[name] = filtered_kp

        return filtered_keypoints
