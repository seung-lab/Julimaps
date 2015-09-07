type Params
  	scaling_factor::Float64

  	# Mesh parameters
	mesh_length::Int64
	mesh_coeff::Float64

	# Matching parameters
	min_dyn_range_ratio::Float64
	block_size::Int64
	search_r::Int64
	min_r::Float64

	# Solver parameters
	match_coeff::Float64
	eta_gradient::Float64
	ftol_gradient::Float64
	eta_newton::Float64
	ftol_newton::Float64
end

function print(p::Params)
  	println("#Params:#######################")
	println("    scaling_factor: $(p.scaling_factor)")
	println("- Mesh parameters:")
	println("    mesh_length: $(p.mesh_length)")
	println("    mesh_coeff: $(p.mesh_coeff)")
	println("- Match parameters:")
	println("    min_dyn_range_ratio: $(p.min_dyn_range_ratio)")
	println("    block_size: $(p.block_size)")
	println("    search_r: $(p.search_r)")
	println("    min_r: $(p.min_r)")
	println("- Solver parameters:")
	println("    match_coeff: $(p.match_coeff)")
	println("    eta_gradient: $(p.eta_gradient)")
	println("    ftol_gradient: $(p.ftol_gradient)")
	println("    eta_newton: $(p.eta_newton)")
	println("    ftol_newton: $(p.ftol_newton)")
  	println("###############################")
end

SCALING_FACTOR_MONTAGE = 1.0
MESH_LENGTH_MONTAGE = 200
MESH_COEFF_MONTAGE = 1.0
MIN_DYN_RANGE_RATIO_MONTAGE = 5
BLOCK_SIZE_MONTAGE = 48
SEARCH_R_MONTAGE = 100
MIN_R_MONTAGE = 0.75
MATCH_COEFF_MONTAGE = 3 
ETA_GRADIENT_MONTAGE = 0.02
FTOL_GRADIENT_MONTAGE = 1/200
ETA_NEWTON_MONTAGE = 0.8
FTOL_NEWTON_MONTAGE = 1/1000000

SCALING_FACTOR_PREALIGNMENT = 0.5
MESH_LENGTH_PREALIGNMENT = 9000		# Specified at scaling factor of 1.0x 
MESH_COEFF_PREALIGNMENT = 1
MIN_DYN_RANGE_RATIO_PREALIGNMENT = 5
BLOCK_SIZE_PREALIGNMENT = 200		# Specified at scaling factor of 1.0x 
SEARCH_R_PREALIGNMENT = 800			# Specified at scaling factor of 1.0x 
MIN_R_PREALIGNMENT = 0.25
MATCH_COEFF_PREALIGNMENT = 20
ETA_GRADIENT_PREALIGNMENT = 0.01
FTOL_GRADIENT_PREALIGNMENT = 1/5000
ETA_NEWTON_PREALIGNMENT = 0.75
FTOL_NEWTON_PREALIGNMENT = 1/1000000

SCALING_FACTOR_ALIGNMENT = 1.0
MESH_LENGTH_ALIGNMENT = 1500
MESH_COEFF_ALIGNMENT = 1.0
MIN_DYN_RANGE_RATIO_ALIGNMENT = 5
BLOCK_SIZE_ALIGNMENT = 500
SEARCH_R_ALIGNMENT = 700
MIN_R_ALIGNMENT = 0.28
MATCH_COEFF_ALIGNMENT = 20
ETA_GRADIENT_ALIGNMENT = 0.01
FTOL_GRADIENT_ALIGNMENT = 1/25000
ETA_NEWTON_ALIGNMENT = 0.5
FTOL_NEWTON_ALIGNMENT = 1/10000000

global PARAMS_MONTAGE = Params(SCALING_FACTOR_MONTAGE, 
								MESH_LENGTH_MONTAGE, 
								MESH_COEFF_MONTAGE, 
								MIN_DYN_RANGE_RATIO_MONTAGE, 
								BLOCK_SIZE_MONTAGE, 
								SEARCH_R_MONTAGE, 
								MIN_R_MONTAGE, 
								MATCH_COEFF_MONTAGE, 
								ETA_GRADIENT_MONTAGE, 
								FTOL_GRADIENT_MONTAGE, 
								ETA_NEWTON_MONTAGE, 
								FTOL_NEWTON_MONTAGE)
global PARAMS_PREALIGNMENT = Params(SCALING_FACTOR_PREALIGNMENT, 
									MESH_LENGTH_PREALIGNMENT, 
									MESH_COEFF_PREALIGNMENT, 
									MIN_DYN_RANGE_RATIO_PREALIGNMENT, 
									BLOCK_SIZE_PREALIGNMENT, 
									SEARCH_R_PREALIGNMENT, 
									MIN_R_PREALIGNMENT, 
									MATCH_COEFF_PREALIGNMENT, 
									ETA_GRADIENT_PREALIGNMENT, 
									FTOL_GRADIENT_PREALIGNMENT, 
									ETA_NEWTON_PREALIGNMENT, 
									FTOL_NEWTON_PREALIGNMENT)
global PARAMS_ALIGNMENT = Params(SCALING_FACTOR_ALIGNMENT, 
								MESH_LENGTH_ALIGNMENT, 
								MESH_COEFF_ALIGNMENT, 
								MIN_DYN_RANGE_RATIO_ALIGNMENT, 
								BLOCK_SIZE_ALIGNMENT, 
								SEARCH_R_ALIGNMENT, 
								MIN_R_ALIGNMENT, 
								MATCH_COEFF_ALIGNMENT, 
								ETA_GRADIENT_ALIGNMENT, 
								FTOL_GRADIENT_ALIGNMENT, 
								ETA_NEWTON_ALIGNMENT, 
								FTOL_NEWTON_ALIGNMENT)

function optimize_all_cores(params::Params)
  	img_d = 2 * (params.search_r + params.block_size) + 1
	optimize_all_cores(img_d)
end