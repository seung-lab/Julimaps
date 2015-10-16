import Base: print

SCALING_FACTOR_MONTAGE = 1.0
MESH_LENGTH_MONTAGE = 175
MESH_COEFF_MONTAGE = 1.0
GAUSSIAN_SIGMA_MONTAGE = 0
MIN_DYN_RANGE_RATIO_MONTAGE = 5
BLOT_THRESHOLD_MONTAGE = 5/255
MAX_BLOTTING_RATIO_MONTAGE = 0.1
BLOCK_SIZE_MONTAGE = 48
SEARCH_R_MONTAGE = 100
MIN_R_MONTAGE = 0.75
OUTLIER_SIGMAS_MONTAGE = 2.0
MATCH_COEFF_MONTAGE = 3.0 
ETA_GRADIENT_MONTAGE = 0.02
FTOL_GRADIENT_MONTAGE = 1/200
ETA_NEWTON_MONTAGE = 0.8
FTOL_NEWTON_MONTAGE = 1/1000000
WRITE_BLOCKMATCHES_MONTAGE = false

SCALING_FACTOR_TRANSLATE = 0.04

SCALING_FACTOR_PREALIGNMENT = 0.5
MESH_LENGTH_PREALIGNMENT = 2500			# Specified at scaling factor of 1.0x 
MESH_COEFF_PREALIGNMENT = 1.0
GAUSSIAN_SIGMA_PREALIGNMENT = 0
MIN_DYN_RANGE_RATIO_PREALIGNMENT = 10
BLOT_THRESHOLD_PREALIGNMENT = 10/255
MAX_BLOTTING_RATIO_PREALIGNMENT = 0.05
BLOCK_SIZE_PREALIGNMENT = 322			# Specified at scaling factor of 1.0x 
SEARCH_R_PREALIGNMENT = 1500			# Specified at scaling factor of 1.0x
MIN_R_PREALIGNMENT = 0.20
OUTLIER_SIGMAS_PREALIGNMENT = 2.0
MATCH_COEFF_PREALIGNMENT = 20.0
ETA_GRADIENT_PREALIGNMENT = 0.01
FTOL_GRADIENT_PREALIGNMENT = 1/5000
ETA_NEWTON_PREALIGNMENT = 0.75
FTOL_NEWTON_PREALIGNMENT = 1/1000000
WRITE_BLOCKMATCHES_PREALIGNMENT = false
GLOBAL_OFFSETS_PREALIGNMENT = false

SCALING_FACTOR_ALIGNMENT = 1.0
MESH_LENGTH_ALIGNMENT = 750
MESH_COEFF_ALIGNMENT = 1.0
GAUSSIAN_SIGMA_ALIGNMENT = 0
MIN_DYN_RANGE_RATIO_ALIGNMENT = 5
BLOT_THRESHOLD_ALIGNMENT = 5/255
MAX_BLOTTING_RATIO_ALIGNMENT = 0.1
BLOCK_SIZE_ALIGNMENT = 184
SEARCH_R_ALIGNMENT = 180
MIN_R_ALIGNMENT = 0.22
OUTLIER_SIGMAS_ALIGNMENT = 2.0
MATCH_COEFF_ALIGNMENT = 20.0
ETA_GRADIENT_ALIGNMENT = 0.01
FTOL_GRADIENT_ALIGNMENT = 1/25000
ETA_NEWTON_ALIGNMENT = 0.5
FTOL_NEWTON_ALIGNMENT = 1/10000000
WRITE_BLOCKMATCHES_ALIGNMENT = false
GLOBAL_OFFSETS_ALIGNMENT = true

global PARAMS_MONTAGE = Dict("scaling_factor" => SCALING_FACTOR_MONTAGE, 
								"mesh_length" => MESH_LENGTH_MONTAGE, 
								"mesh_coeff" => MESH_COEFF_MONTAGE,
								"gaussian_sigma" => GAUSSIAN_SIGMA_MONTAGE,
								"min_dyn_range_ratio" => MIN_DYN_RANGE_RATIO_MONTAGE, 
								"blot_threshold" => BLOT_THRESHOLD_MONTAGE,
								"max_blotting_ratio" => MAX_BLOTTING_RATIO_MONTAGE,
								"block_size" => BLOCK_SIZE_MONTAGE, 
								"search_r" => SEARCH_R_MONTAGE, 
								"min_r" => MIN_R_MONTAGE,
								"outlier_sigmas" => OUTLIER_SIGMAS_MONTAGE,
								"match_coeff" => MATCH_COEFF_MONTAGE, 
								"eta_gradient" => ETA_GRADIENT_MONTAGE, 
								"ftol_gradient" => FTOL_GRADIENT_MONTAGE, 
								"eta_newton" => ETA_NEWTON_MONTAGE, 
								"ftol_newton" => FTOL_NEWTON_MONTAGE,
								"write_blockmatches" => WRITE_BLOCKMATCHES_MONTAGE)

global PARAMS_PREALIGNMENT = Dict("scaling_factor" => SCALING_FACTOR_PREALIGNMENT, 
								"mesh_length" => MESH_LENGTH_PREALIGNMENT, 
								"mesh_coeff" => MESH_COEFF_PREALIGNMENT, 
								"gaussian_sigma" => GAUSSIAN_SIGMA_PREALIGNMENT,
								"min_dyn_range_ratio" => MIN_DYN_RANGE_RATIO_PREALIGNMENT, 
								"blot_threshold" => BLOT_THRESHOLD_PREALIGNMENT,
								"max_blotting_ratio" => MAX_BLOTTING_RATIO_PREALIGNMENT,
								"block_size" => BLOCK_SIZE_PREALIGNMENT, 
								"search_r" => SEARCH_R_PREALIGNMENT, 
								"min_r" => MIN_R_PREALIGNMENT, 
								"outlier_sigmas" => OUTLIER_SIGMAS_PREALIGNMENT,
								"match_coeff" => MATCH_COEFF_PREALIGNMENT, 
								"eta_gradient" => ETA_GRADIENT_PREALIGNMENT, 
								"ftol_gradient" => FTOL_GRADIENT_PREALIGNMENT, 
								"eta_newton" => ETA_NEWTON_PREALIGNMENT, 
								"ftol_newton" => FTOL_NEWTON_PREALIGNMENT,
								"write_blockmatches" => WRITE_BLOCKMATCHES_PREALIGNMENT,
								"global_offsets" => GLOBAL_OFFSETS_PREALIGNMENT)

global PARAMS_ALIGNMENT = Dict("scaling_factor" => SCALING_FACTOR_ALIGNMENT, 
								"mesh_length" => MESH_LENGTH_ALIGNMENT, 
								"mesh_coeff" => MESH_COEFF_ALIGNMENT, 
								"gaussian_sigma" => GAUSSIAN_SIGMA_ALIGNMENT,
								"min_dyn_range_ratio" => MIN_DYN_RANGE_RATIO_ALIGNMENT, 
								"blot_threshold" => BLOT_THRESHOLD_ALIGNMENT,
								"max_blotting_ratio" => MAX_BLOTTING_RATIO_ALIGNMENT,
								"block_size" => BLOCK_SIZE_ALIGNMENT, 
								"search_r" => SEARCH_R_ALIGNMENT, 
								"min_r" => MIN_R_ALIGNMENT, 
								"outlier_sigmas" => OUTLIER_SIGMAS_ALIGNMENT,
								"match_coeff" => MATCH_COEFF_ALIGNMENT, 
								"eta_gradient" => ETA_GRADIENT_ALIGNMENT, 
								"ftol_gradient" => FTOL_GRADIENT_ALIGNMENT, 
								"eta_newton" => ETA_NEWTON_ALIGNMENT, 
								"ftol_newton" => FTOL_NEWTON_ALIGNMENT,
								"write_blockmatches" => WRITE_BLOCKMATCHES_ALIGNMENT,
								"global_offsets" => GLOBAL_OFFSETS_ALIGNMENT)

function optimize_all_cores(params)
  	img_d = 2 * (params["search_r"] + params["block_size"]) + 1
	optimize_all_cores(img_d)
end
