local SumProductInference, parent = torch.class('SumProductInference')


function SumProductInference:__init(y_shape)
	self.batch_size, self.length, self.domain_size = unpack(y_shape)

	self:init_logZ_net()

end

function SumProductInference:inference_net()
	return self.logZ_net
end

function SumProductInference:init_logZ_net()
	local log_edge_potentials = nn.Identity()() -- b x l - 1 x d x d

	local alpha = nn.Constant(torch.zeros(self.batch_size,self.domain_size))(log_edge_potentials)

	for i = 1,(self.length-1) do
		local log_edge_potentials_for_timestep = nn.View(self.batch_size,self.domain_size,self.domain_size)(nn.Narrow(2,i,1)(log_edge_potentials))
	
		alpha_expand = nn.Replicate(self.domain_size,3)(alpha)

		--this does a matrix multiply in log space
		prod = nn.CAddTable()({alpha_expand, log_edge_potentials_for_timestep})
		alpha = nn.LogSumExp(2)(prod)

		alpha = nn.Reshape(self.batch_size,self.domain_size,false)(alpha)
	end

	local logZ = nn.LogSumExp(2)(alpha)
	self.logZ_net = nn.gModule({log_edge_potentials},{logZ})
end


function SumProductInference:infer_values(log_edge_potentials_value)
	local log_Z = self.logZ_net:forward(log_edge_potentials_value)
	local bg = torch.ones(log_Z:size())
	local edge_marginals = self.logZ_net:backward(log_edge_potentials_value, bg)
	return edge_marginals, log_Z
end




