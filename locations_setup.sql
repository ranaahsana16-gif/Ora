-- Create cities table
CREATE TABLE public.cities (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create areas table
CREATE TABLE public.areas (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    city_id UUID REFERENCES public.cities(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create outlets table for pickup
CREATE TABLE public.outlets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Set up RLS for cities
ALTER TABLE public.cities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all users on cities" ON public.cities FOR SELECT USING (true);
CREATE POLICY "Enable all access for admins on cities" ON public.cities FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Set up RLS for areas
ALTER TABLE public.areas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all users on areas" ON public.areas FOR SELECT USING (true);
CREATE POLICY "Enable all access for admins on areas" ON public.areas FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Set up RLS for outlets
ALTER TABLE public.outlets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all users on outlets" ON public.outlets FOR SELECT USING (true);
CREATE POLICY "Enable all access for admins on outlets" ON public.outlets FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Pre-populate "Ora cafe" outlet
INSERT INTO public.outlets (name, address) VALUES ('Ora cafe', 'Main Branch');
